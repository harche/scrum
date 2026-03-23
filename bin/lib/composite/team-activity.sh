#!/bin/bash
# Composite: team-activity <team>
# Per-member sprint items + comment counts for the last 7 days
# Serves: supplements /standup, /team-member

[[ -n "${_COMPOSITE_TEAM_ACTIVITY_LOADED:-}" ]] && return 0
_COMPOSITE_TEAM_ACTIVITY_LOADED=1

cmd_team_activity() {
  local team="${1:?Team required}"

  team_config "$team"

  local sprint_json
  sprint_json=$(team_sprint "$team" active 2>/dev/null) || {
    sprint_json=$(team_sprint "$team" future 2>/dev/null) || {
      echo '{"error":"No active or future sprint found for '"$team"'"}' >&2; return 1
    }
    _log "WARN" "No active sprint — using future sprint"
  }

  local sprint_id
  sprint_id=$(echo "$sprint_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

  # ── Get issues + roster ──────────────────────────────────────────────────
  parallel_init
  parallel_run "issues" cmd_sprint_issues "$sprint_id"
  parallel_run "roster" team_roster "$team"
  parallel_wait_all || true

  local issues_json roster_json
  issues_json=$(parallel_get "issues")
  roster_json=$(parallel_get "roster")

  # ── Get issue keys and fetch comments in parallel ────────────────────────
  local issue_keys
  issue_keys=$(echo "$issues_json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
keys = [i['key'] for i in data.get('issues', [])]
print(' '.join(keys))
")

  parallel_cleanup 2>/dev/null || true
  parallel_init

  for key in $issue_keys; do
    parallel_run "comments_${key}" cmd_comments "$key"
  done
  parallel_wait_all 2>/dev/null || true

  # Collect comments
  local comments_combined="{"
  local first=true
  for key in $issue_keys; do
    local c
    c=$(parallel_get "comments_${key}" 2>/dev/null)
    if [[ -n "$c" && "$c" != *"error"* ]]; then
      [[ "$first" == "true" ]] && first=false || comments_combined+=","
      comments_combined+="\"${key}\":${c}"
    fi
  done
  comments_combined+="}"

  local adf_py
  adf_py="$(cd "$(dirname "${BASH_SOURCE[0]}")/../util" && pwd)/adf.py"

  python3 - "$sprint_json" "$roster_json" "$comments_combined" "$adf_py" "$issues_json" <<'PYEOF'
import json, sys, importlib.util
from datetime import datetime, timedelta, timezone
from collections import Counter

sprint = json.loads(sys.argv[1])
roster = json.loads(sys.argv[2])
all_comments = json.loads(sys.argv[3])
adf_py_path = sys.argv[4]
data = json.loads(sys.argv[5])
issues = data.get("issues", [])

spec = importlib.util.spec_from_file_location("adf", adf_py_path)
adf_mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adf_mod)

cutoff = datetime.now(timezone.utc) - timedelta(days=7)

# Build member activity
member_items = {}
member_comments = Counter()

for issue in issues:
    f = issue.get("fields", {})
    assignee = (f.get("assignee") or {}).get("displayName", "Unassigned")
    status = f.get("status", {}).get("name", "")
    member_items.setdefault(assignee, []).append({
        "key": issue.get("key", ""),
        "summary": f.get("summary", ""),
        "status": status,
        "points": f.get("customfield_10028") or 0,
    })

# Count recent comments
for key, comment_data in all_comments.items():
    for c in comment_data.get("comments", []):
        created = c.get("created", "")
        author = c.get("author", {}).get("displayName", "Unknown")
        try:
            dt = datetime.fromisoformat(created.replace("Z", "+00:00"))
            if dt >= cutoff:
                member_comments[author] += 1
        except (ValueError, TypeError):
            pass

# Build output
members = []
roster_names = {m["name"] for m in roster}
all_names = roster_names | set(member_items.keys()) - {"Unassigned"}

for m in roster:
    name = m["name"]
    items = member_items.get(name, [])
    members.append({
        "name": name,
        "github": m["github"],
        "sprintItems": items,
        "sprintItemCount": len(items),
        "commentCount7d": member_comments.get(name, 0),
        "onRoster": True,
    })

for name in set(member_items.keys()) - roster_names - {"Unassigned"}:
    items = member_items[name]
    members.append({
        "name": name,
        "github": "",
        "sprintItems": items,
        "sprintItemCount": len(items),
        "commentCount7d": member_comments.get(name, 0),
        "onRoster": False,
    })

result = {
    "sprint": {"id": sprint["id"], "name": sprint["name"]},
    "members": sorted(members, key=lambda m: m["sprintItemCount"], reverse=True),
}

print(json.dumps(result))
PYEOF
}

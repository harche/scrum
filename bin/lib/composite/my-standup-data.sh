#!/bin/bash
# Composite: my-standup-data <team>
# Standup data pre-filtered to current user (Jira side only)
# 1 data query (was 2 — removed redundant "recent" search that was unused)
# Serves: /my-standup

[[ -n "${_COMPOSITE_MY_STANDUP_LOADED:-}" ]] && return 0
_COMPOSITE_MY_STANDUP_LOADED=1

cmd_my_standup_data() {
  local team="${1:?Team required}"

  team_config "$team"
  _init_auth

  local user_email="$JIRA_USER"

  local sprint_json
  sprint_json=$(team_sprint "$team" active) || { echo "$sprint_json" >&2; return 1; }

  local sprint_id
  sprint_id=$(echo "$sprint_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

  # Sprint issues only (removed redundant "recent" search — data was unused)
  local issues_json
  issues_json=$(cmd_sprint_issues "$sprint_id")

  # Get my issue keys and fetch comments
  local my_keys
  my_keys=$(python3 -c "
import json, sys
data = json.loads(sys.argv[1])
user = sys.argv[2]
for i in data.get('issues', []):
    a = (i.get('fields', {}).get('assignee') or {})
    if a.get('emailAddress', '') == user or a.get('displayName', '') == user:
        print(i['key'])
" "$issues_json" "$user_email")

  parallel_init
  for key in $my_keys; do
    parallel_run "comments_${key}" cmd_comments "$key"
  done
  parallel_wait_all 2>/dev/null || true

  local comments_combined="{"
  local first=true
  for key in $my_keys; do
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

  python3 - "$sprint_json" "$issues_json" "$comments_combined" "$user_email" "$adf_py" <<'PYEOF'
import json, sys, importlib.util
from datetime import datetime, timedelta, timezone

sprint = json.loads(sys.argv[1])
all_issues = json.loads(sys.argv[2])
all_comments = json.loads(sys.argv[3])
user_email = sys.argv[4]
adf_py_path = sys.argv[5]

spec = importlib.util.spec_from_file_location("adf", adf_py_path)
adf_mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adf_mod)

start = datetime.fromisoformat(sprint["startDate"].replace("Z", "+00:00"))
end = datetime.fromisoformat(sprint["endDate"].replace("Z", "+00:00"))
now = datetime.now(timezone.utc)
total_days = max((end - start).days, 1)
elapsed = min(max((now - start).days, 0), total_days)

# Filter to my items
done = []
in_progress = []
blocked = []
todo = []

for i in all_issues.get("issues", []):
    f = i.get("fields", {})
    a = f.get("assignee") or {}
    if a.get("emailAddress", "") != user_email and a.get("displayName", "") != user_email:
        continue

    key = i.get("key", "")
    status_cat = f.get("status", {}).get("statusCategory", {}).get("key", "")
    status_name = f.get("status", {}).get("name", "")
    is_blocked = (f.get("customfield_10517") or {}).get("value", "False") == "True"
    br = f.get("customfield_10483")
    br_text = adf_mod.adf_to_text(br).strip() if isinstance(br, dict) else ""

    item = {"key": key, "summary": f.get("summary", ""), "status": status_name,
            "points": f.get("customfield_10028") or 0, "type": f.get("issuetype", {}).get("name", ""),
            "blocked": is_blocked, "blockedReason": br_text}

    if status_cat == "done":
        done.append(item)
    elif is_blocked:
        blocked.append(item)
    elif status_cat == "new" or status_name in ("To Do", "NEW"):
        todo.append(item)
    else:
        in_progress.append(item)

# Recent comments on my items
my_comments = []
cutoff = now - timedelta(days=7)
for key, cdata in all_comments.items():
    for c in cdata.get("comments", []):
        created = c.get("created", "")
        try:
            dt = datetime.fromisoformat(created.replace("Z", "+00:00"))
            if dt >= cutoff:
                body = c.get("body", {})
                my_comments.append({
                    "key": key, "author": c.get("author", {}).get("displayName", ""),
                    "created": created,
                    "body": adf_mod.adf_to_text(body).strip() if isinstance(body, dict) else str(body),
                })
        except (ValueError, TypeError):
            pass

result = {
    "sprint": {"id": sprint["id"], "name": sprint["name"],
               "daysElapsed": elapsed, "daysTotal": total_days},
    "done": done,
    "inProgress": in_progress,
    "blocked": blocked,
    "upNext": todo,
    "recentComments": my_comments,
    "summary": {"done": len(done), "inProgress": len(in_progress),
                "blocked": len(blocked), "toDo": len(todo)},
}
print(json.dumps(result))
PYEOF
}

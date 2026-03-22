#!/bin/bash
# Composite: standup-data <team> [--stream]
# Returns sprint dashboard + recent updates + new bugs + per-member comments
# 2 data queries (was 3 — removed redundant "recent" search, derived from updated field)
# Serves: /standup, /my-standup, /team-member

[[ -n "${_COMPOSITE_STANDUP_DATA_LOADED:-}" ]] && return 0
_COMPOSITE_STANDUP_DATA_LOADED=1

cmd_standup_data() {
  local team="${1:?Team required (e.g., 'Node Devices' or 'Node Core')}"
  local stream=false
  [[ "${2:-}" == "--stream" ]] && stream=true

  # ── Resolve team config ──────────────────────────────────────────────────
  team_config "$team"

  # ── Get sprint info ──────────────────────────────────────────────────────
  local sprint_json
  sprint_json=$(team_sprint "$team" active) || {
    echo "$sprint_json" >&2; return 1
  }

  local sprint_id
  sprint_id=$(echo "$sprint_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

  # ── Parallel: sprint issues (with updated field) + new bugs + roster ────
  parallel_init

  parallel_run "issues" cmd_sprint_issues "$sprint_id" 100 "${ISSUE_FIELDS},updated"
  parallel_run "new_bugs" cmd_search "project = OCPBUGS AND component in (${TEAM_BUG_COMPONENTS}) AND created >= -7d ORDER BY created DESC" 50
  parallel_run "roster" team_roster "$team"

  parallel_wait_all || true

  local issues_json bugs_json roster_json
  issues_json=$(parallel_get "issues")
  bugs_json=$(parallel_get "new_bugs")
  roster_json=$(parallel_get "roster")

  # ── Get issue keys for comment fetching ──────────────────────────────────
  local issue_keys
  issue_keys=$(echo "$issues_json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
keys = [i['key'] for i in data.get('issues', [])]
print(' '.join(keys))
")

  # ── Fetch comments in parallel (batch of 5) ─────────────────────────────
  # Re-init parallel for comment batch
  parallel_cleanup 2>/dev/null || true
  parallel_init

  local count=0
  for key in $issue_keys; do
    parallel_run "comments_${key}" cmd_comments "$key"
    count=$((count + 1))
    if (( count % 5 == 0 )); then
      parallel_wait_all 2>/dev/null || true
    fi
  done
  parallel_wait_all 2>/dev/null || true

  # Collect all comments into a JSON object keyed by issue key
  local comments_combined="{"
  local first=true
  for key in $issue_keys; do
    local c
    c=$(parallel_get "comments_${key}" 2>/dev/null)
    if [[ -n "$c" && "$c" != *"error"* ]]; then
      if [[ "$first" == "true" ]]; then
        first=false
      else
        comments_combined+=","
      fi
      comments_combined+="\"${key}\":${c}"
    fi
  done
  comments_combined+="}"

  # ── Process everything in Python ─────────────────────────────────────────
  local adf_py
  adf_py="$(cd "$(dirname "${BASH_SOURCE[0]}")/../util" && pwd)/adf.py"

  python3 - "$sprint_json" "$roster_json" "$bugs_json" "$comments_combined" "$adf_py" "$issues_json" <<'PYEOF'
import json, sys, importlib.util
from datetime import datetime, timedelta, timezone
from collections import Counter

sprint = json.loads(sys.argv[1])
roster = json.loads(sys.argv[2])
bugs_data = json.loads(sys.argv[3])
all_comments = json.loads(sys.argv[4])
adf_py_path = sys.argv[5]
data = json.loads(sys.argv[6])
issues = data.get("issues", [])

# Load ADF converter
spec = importlib.util.spec_from_file_location("adf", adf_py_path)
adf_mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adf_mod)

# Sprint progress
start = datetime.fromisoformat(sprint["startDate"].replace("Z", "+00:00"))
end = datetime.fromisoformat(sprint["endDate"].replace("Z", "+00:00"))
now = datetime.now(timezone.utc)
total_days = max((end - start).days, 1)
elapsed_days = min(max((now - start).days, 0), total_days)
days_remaining = max(total_days - elapsed_days, 0)
cutoff = now - timedelta(days=7)

# Categorize issues
STATUS_ORDER = {"done": 0, "codeReview": 1, "inProgress": 2, "modified": 3, "toDo": 4, "other": 5}
status_groups = {}
team_workload = {}
total_points = 0
done_points = 0
blocked_items = []
at_risk = []
discussion_topics = []
_shape_warned = set()

for issue in issues:
    f = issue.get("fields", {})
    key = issue.get("key", "")
    summary = f.get("summary", "")
    status_name = f.get("status", {}).get("name", "Unknown")
    status_cat = f.get("status", {}).get("statusCategory", {}).get("key", "")
    assignee_name = (f.get("assignee") or {}).get("displayName", "Unassigned")
    points = f.get("customfield_10028") or 0
    issue_type = f.get("issuetype", {}).get("name", "")
    priority = f.get("priority", {}).get("name", "")
    blocked_raw = f.get("customfield_10517")
    if blocked_raw is not None and not isinstance(blocked_raw, dict) and "blocked" not in _shape_warned:
        print(f"SHAPE WARNING: Blocked field (customfield_10517) is {type(blocked_raw).__name__}, "
              f"expected dict or None (on {key}). Blocker detection may be broken.", file=sys.stderr)
        _shape_warned.add("blocked")
    blocked_val = (blocked_raw or {}).get("value", "False") if isinstance(blocked_raw, dict) else "False"
    release_blocker = f.get("customfield_10847")

    total_points += points

    if status_cat == "done":
        group = "done"
        done_points += points
    elif status_name == "Code Review":
        group = "codeReview"
    elif status_name == "MODIFIED":
        group = "modified"
    elif status_cat == "indeterminate" or status_name == "In Progress":
        group = "inProgress"
    elif status_cat == "new" or status_name in ("To Do", "NEW"):
        group = "toDo"
    else:
        group = "other"

    item = {
        "key": key, "summary": summary, "status": status_name,
        "statusGroup": group, "assignee": assignee_name,
        "points": points, "type": issue_type, "priority": priority,
        "blocked": blocked_val == "True", "releaseBlocker": release_blocker,
    }
    status_groups.setdefault(group, []).append(item)

    if blocked_val == "True":
        blocked_items.append(item)
    if group not in ("done",) and days_remaining <= 3:
        at_risk.append(item)

    # Discussion topics
    if not points and group != "done":
        discussion_topics.append({"key": key, "summary": summary, "reason": "No story points"})
    if assignee_name == "Unassigned" and group != "done":
        discussion_topics.append({"key": key, "summary": summary, "reason": "Unassigned"})

    # Workload
    wl = team_workload.setdefault(assignee_name, {
        "member": assignee_name,
        "toDo": 0, "inProgress": 0, "codeReview": 0, "modified": 0,
        "done": 0, "other": 0, "total": 0,
        "pointsDone": 0, "pointsTotal": 0, "commentCount7d": 0,
    })
    wl[group] = wl.get(group, 0) + 1
    wl["total"] += 1
    wl["pointsTotal"] += points
    if group == "done":
        wl["pointsDone"] += points

# Process comments — extract recent ones, count per member
for key, comment_data in all_comments.items():
    for c in comment_data.get("comments", []):
        created = c.get("created", "")
        author = c.get("author", {}).get("displayName", "Unknown")
        try:
            dt = datetime.fromisoformat(created.replace("Z", "+00:00"))
            if dt >= cutoff:
                if author in team_workload:
                    team_workload[author]["commentCount7d"] += 1
                else:
                    team_workload.setdefault(author, {
                        "member": author, "toDo": 0, "inProgress": 0, "codeReview": 0,
                        "modified": 0, "done": 0, "other": 0, "total": 0,
                        "pointsDone": 0, "pointsTotal": 0, "commentCount7d": 1,
                    })
        except (ValueError, TypeError):
            pass

# New bugs
new_bugs = []
for bug in bugs_data.get("issues", []):
    bf = bug.get("fields", {})
    new_bugs.append({
        "key": bug.get("key", ""),
        "summary": bf.get("summary", ""),
        "priority": bf.get("priority", {}).get("name", ""),
        "status": bf.get("status", {}).get("name", ""),
        "assignee": (bf.get("assignee") or {}).get("displayName", "Unassigned"),
    })

# Recently updated keys (derived from sprint issues' updated field — was a separate query)
recent_keys = []
for issue in issues:
    updated = issue.get("fields", {}).get("updated", "")
    if updated:
        try:
            dt = datetime.fromisoformat(updated.replace("Z", "+00:00"))
            if dt >= cutoff:
                recent_keys.append(issue.get("key", ""))
        except (ValueError, TypeError):
            pass

# Build roster
roster_out = []
active_members = set(team_workload.keys())
for m in roster:
    name = m["name"]
    wl = team_workload.get(name, {})
    roster_out.append({
        "name": name, "github": m["github"],
        "hasItems": name in active_members,
        "sprintItems": wl.get("total", 0),
        "commentCount7d": wl.get("commentCount7d", 0),
        "statusSummary": {g: wl.get(g, 0) for g in STATUS_ORDER if wl.get(g, 0) > 0},
    })
# Non-roster assignees
roster_names = {m["name"] for m in roster}
for name in active_members - roster_names - {"Unassigned"}:
    wl = team_workload[name]
    roster_out.append({
        "name": name, "github": "", "hasItems": True, "offRoster": True,
        "sprintItems": wl.get("total", 0),
        "commentCount7d": wl.get("commentCount7d", 0),
        "statusSummary": {g: wl.get(g, 0) for g in STATUS_ORDER if wl.get(g, 0) > 0},
    })

by_status = {}
for group in sorted(status_groups.keys(), key=lambda g: STATUS_ORDER.get(g, 99)):
    by_status[group] = status_groups[group]

result = {
    "sprint": {
        "id": sprint["id"], "name": sprint["name"],
        "startDate": sprint["startDate"], "endDate": sprint["endDate"],
        "goal": sprint.get("goal", ""),
        "daysElapsed": elapsed_days, "daysTotal": total_days, "daysRemaining": days_remaining,
    },
    "summary": {
        "total": len(issues),
        "done": len(status_groups.get("done", [])),
        "codeReview": len(status_groups.get("codeReview", [])),
        "inProgress": len(status_groups.get("inProgress", [])),
        "modified": len(status_groups.get("modified", [])),
        "toDo": len(status_groups.get("toDo", [])),
        "other": len(status_groups.get("other", [])),
        "totalPoints": total_points,
        "donePoints": done_points,
    },
    "byStatus": by_status,
    "blockers": blocked_items,
    "atRisk": at_risk,
    "newBugs": new_bugs,
    "recentlyUpdatedKeys": recent_keys,
    "discussionTopics": discussion_topics,
    "memberActivity": roster_out,
    "teamWorkload": sorted(team_workload.values(), key=lambda w: w["total"], reverse=True),
}

print(json.dumps(result))
PYEOF
}

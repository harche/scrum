#!/bin/bash
# Composite: sprint-dashboard <team> [--stream]
# Returns sprint info + issues grouped by status + workload + blockers
# Serves: /sprint-status, /team-load, /sprint-review, /my-board

[[ -n "${_COMPOSITE_SPRINT_DASHBOARD_LOADED:-}" ]] && return 0
_COMPOSITE_SPRINT_DASHBOARD_LOADED=1

cmd_sprint_dashboard() {
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

  # ── Get sprint issues + roster in parallel ───────────────────────────────
  parallel_init
  parallel_run "issues" cmd_sprint_issues "$sprint_id"
  parallel_run "roster" team_roster "$team"
  parallel_wait_all || true

  local issues_json roster_json
  issues_json=$(parallel_get "issues")
  roster_json=$(parallel_get "roster")

  # ── Process everything in Python for speed ───────────────────────────────
  python3 - "$sprint_json" "$roster_json" "$issues_json" <<'PYEOF'
import json, sys
from datetime import datetime, timezone

sprint = json.loads(sys.argv[1])
roster = json.loads(sys.argv[2])
data = json.loads(sys.argv[3])
issues = data.get("issues", [])

# Sprint progress
start = datetime.fromisoformat(sprint["startDate"].replace("Z", "+00:00"))
end = datetime.fromisoformat(sprint["endDate"].replace("Z", "+00:00"))
now = datetime.now(timezone.utc)
total_days = max((end - start).days, 1)
elapsed_days = min(max((now - start).days, 0), total_days)
days_remaining = max(total_days - elapsed_days, 0)

# Categorize issues
status_groups = {}
team_workload = {}
total_points = 0
done_points = 0
blocked_items = []
at_risk = []

STATUS_ORDER = {"done": 0, "codeReview": 1, "inProgress": 2, "modified": 3, "toDo": 4, "other": 5}

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
    blocked_val = (f.get("customfield_10517") or {}).get("value", "False")
    blocked_reason_adf = f.get("customfield_10483")
    release_blocker = f.get("customfield_10847")

    total_points += points

    # Map status to group
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
        "key": key,
        "summary": summary,
        "status": status_name,
        "statusGroup": group,
        "assignee": assignee_name,
        "points": points,
        "type": issue_type,
        "priority": priority,
        "blocked": blocked_val == "True",
        "releaseBLocker": release_blocker,
    }

    status_groups.setdefault(group, []).append(item)

    # Track blocked items
    if blocked_val == "True":
        blocked_items.append(item)

    # At risk: not done, with sprint ending soon
    if group not in ("done",) and days_remaining <= 3:
        at_risk.append(item)

    # Workload tracking
    wl = team_workload.setdefault(assignee_name, {
        "member": assignee_name,
        "toDo": 0, "inProgress": 0, "codeReview": 0, "modified": 0,
        "done": 0, "other": 0, "total": 0,
        "pointsDone": 0, "pointsTotal": 0,
    })
    wl[group] = wl.get(group, 0) + 1
    wl["total"] += 1
    wl["pointsTotal"] += points
    if group == "done":
        wl["pointsDone"] += points

# Sort groups by status order
by_status = {}
for group in sorted(status_groups.keys(), key=lambda g: STATUS_ORDER.get(g, 99)):
    by_status[group] = status_groups[group]

# Build roster with hasItems flag
roster_out = []
active_members = set(team_workload.keys())
for m in roster:
    roster_out.append({
        "name": m["name"],
        "github": m["github"],
        "hasItems": m["name"] in active_members,
    })
# Add non-roster assignees
roster_names = {m["name"] for m in roster}
for name in active_members - roster_names:
    if name != "Unassigned":
        roster_out.append({"name": name, "github": "", "hasItems": True, "offRoster": True})

result = {
    "sprint": {
        "id": sprint["id"],
        "name": sprint["name"],
        "startDate": sprint["startDate"],
        "endDate": sprint["endDate"],
        "goal": sprint.get("goal", ""),
        "daysElapsed": elapsed_days,
        "daysTotal": total_days,
        "daysRemaining": days_remaining,
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
    "teamWorkload": sorted(team_workload.values(), key=lambda w: w["total"], reverse=True),
    "roster": roster_out,
}

print(json.dumps(result))
PYEOF
}

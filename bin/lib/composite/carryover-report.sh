#!/bin/bash
# Composite: carryover-report <team>
# Returns not-done items with carryover context
# Serves: /carryovers

[[ -n "${_COMPOSITE_CARRYOVER_LOADED:-}" ]] && return 0
_COMPOSITE_CARRYOVER_LOADED=1

cmd_carryover_report() {
  local team="${1:?Team required}"

  team_config "$team"

  # Get active and future sprint info + issues in parallel
  parallel_init
  parallel_run "active_sprint" team_sprint "$team" active
  parallel_run "future_sprint" bash -c "source '${SCRIPT_DIR}/lib/core.sh'; source '${SCRIPT_DIR}/lib/api/sprint.sh'; source '${SCRIPT_DIR}/lib/team.sh'; team_sprint '$team' future 2>/dev/null || echo '{\"error\":\"No future sprint\"}'"
  parallel_wait_all || true

  local active_sprint future_sprint
  active_sprint=$(parallel_get "active_sprint")
  future_sprint=$(parallel_get "future_sprint")

  local sprint_id
  sprint_id=$(echo "$active_sprint" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))")

  # Fetch sprint issues
  local issues_json
  issues_json=$(cmd_sprint_issues "$sprint_id")

  python3 - "$active_sprint" "$future_sprint" "$issues_json" <<'PYEOF'
import json, sys
from datetime import datetime, timezone

sprint = json.loads(sys.argv[1])
future = json.loads(sys.argv[2])
data = json.loads(sys.argv[3])
issues = data.get("issues", [])

carryovers = []
done_items = []

for issue in issues:
    f = issue.get("fields", {})
    status_cat = f.get("status", {}).get("statusCategory", {}).get("key", "")
    key = issue.get("key", "")
    summary = f.get("summary", "")
    status_name = f.get("status", {}).get("name", "")
    assignee = (f.get("assignee") or {}).get("displayName", "Unassigned")
    points = f.get("customfield_10028") or 0
    issue_type = f.get("issuetype", {}).get("name", "")
    blocked = (f.get("customfield_10517") or {}).get("value", "False") == "True"

    item = {
        "key": key, "summary": summary, "status": status_name,
        "assignee": assignee, "points": points, "type": issue_type,
        "blocked": blocked,
    }

    if status_cat == "done":
        done_items.append(item)
    else:
        # Count how many sprints this has been in
        sprints_in = len([s for s in (f.get("customfield_10020") or []) if s.get("state") == "closed"])
        item["previousSprints"] = sprints_in
        carryovers.append(item)

# Stats
by_assignee = {}
for c in carryovers:
    a = c["assignee"]
    by_assignee.setdefault(a, []).append(c["key"])

result = {
    "activeSprint": sprint,
    "futureSprint": future if "error" not in future else None,
    "carryovers": carryovers,
    "doneItems": done_items,
    "stats": {
        "totalItems": len(issues),
        "doneCount": len(done_items),
        "carryoverCount": len(carryovers),
        "carryoverPoints": sum(c["points"] for c in carryovers),
        "donePoints": sum(d["points"] for d in done_items),
        "byAssignee": {a: len(keys) for a, keys in by_assignee.items()},
    },
}

print(json.dumps(result))
PYEOF
}

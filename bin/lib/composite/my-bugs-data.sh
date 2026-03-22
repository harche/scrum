#!/bin/bash
# Composite: my-bugs-data <team>
# All bugs assigned to the current user, categorized
# Serves: /my-bugs

[[ -n "${_COMPOSITE_MY_BUGS_LOADED:-}" ]] && return 0
_COMPOSITE_MY_BUGS_LOADED=1

cmd_my_bugs_data() {
  local team="${1:?Team required}"

  team_config "$team"

  # _init_auth is called by _curl inside cmd_search, but we need JIRA_USER now
  _init_auth
  local user_email="$JIRA_USER"

  local search_result
  search_result=$(cmd_search "project = OCPBUGS AND component in (${TEAM_BUG_COMPONENTS}) AND assignee = \"${user_email}\" AND status not in (CLOSED, Verified, Done) ORDER BY priority ASC, created ASC" 100)

  python3 - "$TEAM_NAME" "$search_result" <<'PYEOF'
import json, sys
from datetime import datetime, timezone

team_name = sys.argv[1]
data = json.loads(sys.argv[2])
issues = data.get("issues", [])
now = datetime.now(timezone.utc)

all_bugs = []
escalations = []
release_blockers = []
by_priority = {}

for issue in issues:
    f = issue.get("fields", {})
    key = issue.get("key", "")
    summary = f.get("summary", "")
    status = f.get("status", {}).get("name", "")
    priority = f.get("priority", {}).get("name", "")
    pts = f.get("customfield_10028") or 0
    sfdc = f.get("customfield_10978")
    rb = f.get("customfield_10847")
    fv = [v.get("name", "") for v in (f.get("fixVersions") or [])]
    blocked = (f.get("customfield_10517") or {}).get("value", "False") == "True"

    bug = {"key": key, "summary": summary, "status": status, "priority": priority,
           "points": pts, "fixVersions": fv, "blocked": blocked,
           "sfdcCaseCount": sfdc, "releaseBlocker": rb}
    all_bugs.append(bug)
    by_priority[priority] = by_priority.get(priority, 0) + 1

    if sfdc:
        escalations.append(bug)
    if rb:
        release_blockers.append(bug)

result = {
    "team": team_name,
    "summary": {
        "total": len(all_bugs),
        "byPriority": by_priority,
        "customerEscalations": len(escalations),
        "releaseBlockers": len(release_blockers),
    },
    "customerEscalations": escalations,
    "releaseBlockers": release_blockers,
    "allBugs": all_bugs,
}
print(json.dumps(result))
PYEOF
}

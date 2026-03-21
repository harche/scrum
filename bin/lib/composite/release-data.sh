#!/bin/bash
# Composite: release-data <team> [version]
# Release readiness: blockers, open bugs, epics
# Serves: /release-check

[[ -n "${_COMPOSITE_RELEASE_DATA_LOADED:-}" ]] && return 0
_COMPOSITE_RELEASE_DATA_LOADED=1

cmd_release_data() {
  local team="${1:?Team required}"
  local version="${2:-}"

  team_config "$team"

  # ── Version discovery if not provided ────────────────────────────────────
  if [[ -z "$version" ]]; then
    version=$(cmd_search "project = OCPNODE AND fixVersion is not EMPTY AND status not in (Closed, Done) ORDER BY fixVersion DESC" 10 | \
      python3 -c "
import sys, json
versions = set()
for i in json.load(sys.stdin).get('issues', []):
    for v in i['fields'].get('fixVersions', []):
        versions.add(v['name'])
if versions:
    print(sorted(versions)[-1])
else:
    print('')
")
    if [[ -z "$version" ]]; then
      echo '{"error":"No active fixVersion found"}' >&2
      return 1
    fi
  fi

  # ── Parallel searches ───────────────────────────────────────────────────
  parallel_init

  parallel_run "approved_blockers" cmd_search \
    "project = OCPBUGS AND component in (${TEAM_BUG_COMPONENTS}) AND \"Release Blocker\" = \"Approved\" AND fixVersion = \"${version}\" AND status not in (Closed, Done, Verified) ORDER BY priority ASC" 50

  parallel_run "proposed_blockers" cmd_search \
    "project = OCPBUGS AND component in (${TEAM_BUG_COMPONENTS}) AND \"Release Blocker\" = \"Proposed\" AND fixVersion = \"${version}\" AND status not in (Closed, Done, Verified) ORDER BY priority ASC" 50

  parallel_run "open_bugs" cmd_search \
    "project = OCPBUGS AND component in (${TEAM_BUG_COMPONENTS}) AND fixVersion = \"${version}\" AND status not in (Closed, Done, Verified) ORDER BY priority ASC" 50

  parallel_run "epics" cmd_search \
    "project = OCPNODE AND issuetype = Epic AND component in (${TEAM_BUG_COMPONENTS}) AND fixVersion = \"${version}\" ORDER BY status ASC" 50

  parallel_wait_all || true

  python3 - "$version" \
    "$(parallel_get approved_blockers)" \
    "$(parallel_get proposed_blockers)" \
    "$(parallel_get open_bugs)" \
    "$(parallel_get epics)" \
    <<'PYEOF'
import json, sys

version = sys.argv[1]

def extract(data_str):
    items = []
    for i in json.loads(data_str).get("issues", []):
        f = i.get("fields", {})
        items.append({
            "key": i.get("key", ""),
            "summary": f.get("summary", ""),
            "status": f.get("status", {}).get("name", ""),
            "assignee": (f.get("assignee") or {}).get("displayName", "Unassigned"),
            "priority": f.get("priority", {}).get("name", ""),
            "points": f.get("customfield_10028") or 0,
        })
    return items

approved = extract(sys.argv[2])
proposed = extract(sys.argv[3])
open_bugs = extract(sys.argv[4])
epics = extract(sys.argv[5])

result = {
    "version": version,
    "summary": {
        "approvedBlockers": len(approved),
        "proposedBlockers": len(proposed),
        "openBugs": len(open_bugs),
        "epics": len(epics),
    },
    "approvedBlockers": approved,
    "proposedBlockers": proposed,
    "openBugs": open_bugs,
    "epics": epics,
}

print(json.dumps(result))
PYEOF
}

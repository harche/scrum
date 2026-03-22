#!/bin/bash
# Composite: release-data <team> [version]
# Release readiness: blockers, open bugs, epics
# 2 queries for bugs+epics (was 4 — approved/proposed/all merged into 1)
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

  # ── 2 queries (was 4): all bugs + epics — categorize blockers in Python ──
  parallel_init

  parallel_run "all_bugs" cmd_search \
    "project = OCPBUGS AND component in (${TEAM_BUG_COMPONENTS}) AND fixVersion = \"${version}\" AND status not in (Closed, Done, Verified) ORDER BY priority ASC" 100

  parallel_run "epics" cmd_search \
    "project = OCPNODE AND issuetype = Epic AND component in (${TEAM_BUG_COMPONENTS}) AND fixVersion = \"${version}\" ORDER BY status ASC" 50

  parallel_wait_all || true

  python3 - "$version" \
    "$(parallel_get all_bugs)" \
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
            "releaseBlocker": f.get("customfield_10847"),
        })
    return items

all_bugs = extract(sys.argv[2])
epics = extract(sys.argv[3])

# Shape assertion — warn if releaseBlocker format changed
for b in all_bugs[:5]:
    rb = b.get("releaseBlocker")
    if rb is not None and not isinstance(rb, dict):
        print(f"SHAPE WARNING: releaseBlocker is {type(rb).__name__}, expected dict or None "
              f"(on {b['key']}). Blocker categorization may be broken.", file=sys.stderr)
        break

# Categorize blockers from all bugs (was 2 separate JQL queries)
approved = [b for b in all_bugs
            if isinstance(b.get("releaseBlocker"), dict)
            and b["releaseBlocker"].get("value") == "Approved"]
proposed = [b for b in all_bugs
            if isinstance(b.get("releaseBlocker"), dict)
            and b["releaseBlocker"].get("value") == "Proposed"]

# Canary: if all bugs have releaseBlocker set but none match known values, values may have changed
bugs_with_rb = [b for b in all_bugs if b.get("releaseBlocker") is not None]
if len(bugs_with_rb) > 5 and len(approved) == 0 and len(proposed) == 0:
    print(f"CANARY: {len(bugs_with_rb)} bugs have releaseBlocker set but 0 match "
          f"'Approved' or 'Proposed'. Field values may have changed.", file=sys.stderr)

result = {
    "version": version,
    "summary": {
        "approvedBlockers": len(approved),
        "proposedBlockers": len(proposed),
        "openBugs": len(all_bugs),
        "epics": len(epics),
    },
    "approvedBlockers": approved,
    "proposedBlockers": proposed,
    "openBugs": all_bugs,
    "epics": epics,
}

print(json.dumps(result))
PYEOF
}

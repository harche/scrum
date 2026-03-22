#!/bin/bash
# Composite: bug-overview <team> [--stream]
# Runs 6+ bug searches in parallel, returns categorized bug data
# Serves: /bug-triage, /my-bugs

[[ -n "${_COMPOSITE_BUG_OVERVIEW_LOADED:-}" ]] && return 0
_COMPOSITE_BUG_OVERVIEW_LOADED=1

cmd_bug_overview() {
  local team="${1:?Team required (e.g., 'Node Devices' or 'Node Core')}"

  # ── Resolve team config ──────────────────────────────────────────────────
  team_config "$team"

  local comp_filter="component in (${TEAM_BUG_COMPONENTS})"

  # ── Build assignee filter from roster ────────────────────────────────────
  local roster_json
  roster_json=$(team_roster "$team")
  local assignee_emails
  assignee_emails=$(echo "$roster_json" | python3 -c "
import json, sys
# We need emails, but roster only has names/github handles.
# Build a JQL-compatible list of display names for assignee matching.
members = json.load(sys.stdin)
names = [m['name'] for m in members]
# JQL assignee filter using displayName via 'assignee in membersOf()' won't work,
# so we build an OR clause: assignee = 'Name1' OR assignee = 'Name2' ...
clauses = ' OR '.join(f'assignee = \"{n}\"' for n in names)
print(clauses)
")

  # ── Run all searches in parallel ─────────────────────────────────────────
  parallel_init

  # Untriaged: priority Undefined or Unprioritized
  parallel_run "untriaged" cmd_search \
    "project = OCPBUGS AND ${comp_filter} AND priority in (Undefined, Unprioritized) AND status not in (Closed, Done, Verified) ORDER BY created DESC" 50

  # Unassigned
  parallel_run "unassigned" cmd_search \
    "project = OCPBUGS AND ${comp_filter} AND assignee is EMPTY AND status not in (Closed, Done, Verified) ORDER BY priority ASC, created DESC" 50

  # Release blocker proposals
  parallel_run "blocker_proposals" cmd_search \
    "project = OCPBUGS AND ${comp_filter} AND \"Release Blocker\" = \"Proposed\" AND status not in (Closed, Done, Verified) ORDER BY priority ASC" 50

  # Customer escalations (SFDC cases)
  parallel_run "escalations" cmd_search \
    "project = OCPBUGS AND ${comp_filter} AND \"SFDC Cases Counter\" is not EMPTY AND status not in (Closed, Done, Verified) ORDER BY priority ASC" 50

  # New bugs this week
  parallel_run "new_this_week" cmd_search \
    "project = OCPBUGS AND ${comp_filter} AND created >= -7d ORDER BY created DESC" 50

  # All open bugs (by component)
  parallel_run "all_open" cmd_search \
    "project = OCPBUGS AND ${comp_filter} AND status not in (Closed, Done, Verified) ORDER BY priority ASC, created DESC" 100

  # Bugs assigned to team members outside ALL Node components (truly out-of-scope or untagged)
  parallel_run "team_no_component" cmd_search \
    "project = OCPBUGS AND (${assignee_emails}) AND (component is EMPTY OR component not in (${ALL_NODE_COMPONENTS})) AND status not in (Closed, Done, Verified) ORDER BY priority ASC, created DESC" 50

  parallel_wait_all || true

  # ── Assemble results ────────────────────────────────────────────────────
  python3 - \
    "$(parallel_get untriaged)" \
    "$(parallel_get unassigned)" \
    "$(parallel_get blocker_proposals)" \
    "$(parallel_get escalations)" \
    "$(parallel_get new_this_week)" \
    "$(parallel_get all_open)" \
    "$(parallel_get team_no_component)" \
    <<'PYEOF'
import json, sys

def extract_bugs(data_str):
    data = json.loads(data_str)
    bugs = []
    for i in data.get("issues", []):
        f = i.get("fields", {})
        components = [c.get("name", "") for c in (f.get("components") or [])]
        bugs.append({
            "key": i.get("key", ""),
            "summary": f.get("summary", ""),
            "status": f.get("status", {}).get("name", ""),
            "priority": f.get("priority", {}).get("name", ""),
            "assignee": (f.get("assignee") or {}).get("displayName", "Unassigned"),
            "points": f.get("customfield_10028") or 0,
            "releaseBlocker": f.get("customfield_10847"),
            "fixVersions": [v.get("name", "") for v in (f.get("fixVersions") or [])],
            "components": components,
        })
    return bugs

untriaged = extract_bugs(sys.argv[1])
unassigned = extract_bugs(sys.argv[2])
blocker_proposals = extract_bugs(sys.argv[3])
escalations = extract_bugs(sys.argv[4])
new_this_week = extract_bugs(sys.argv[5])
all_open = extract_bugs(sys.argv[6])
missing_component = extract_bugs(sys.argv[7])

# Merge missing-component bugs into allOpen (deduplicated)
all_open_keys = {b["key"] for b in all_open}
for b in missing_component:
    if b["key"] not in all_open_keys:
        all_open.append(b)
        all_open_keys.add(b["key"])

result = {
    "summary": {
        "totalOpen": len(all_open),
        "untriaged": len(untriaged),
        "unassigned": len(unassigned),
        "blockerProposals": len(blocker_proposals),
        "customerEscalations": len(escalations),
        "newThisWeek": len(new_this_week),
        "missingComponent": len(missing_component),
    },
    "untriaged": untriaged,
    "unassigned": unassigned,
    "blockerProposals": blocker_proposals,
    "customerEscalations": escalations,
    "newThisWeek": new_this_week,
    "missingComponent": missing_component,
    "allOpen": all_open,
}

print(json.dumps(result))
PYEOF
}

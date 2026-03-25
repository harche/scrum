#!/bin/bash
# Composite: bug-overview <team>
# Fetches all open bugs in 3 queries (was 7), categorizes in Python
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
members = json.load(sys.stdin)
names = [m['name'] for m in members]
clauses = ' OR '.join(f'assignee = \"{n}\"' for n in names)
print(clauses)
")

  # ── Extended fields: include SFDC counter for escalation categorization ──
  local bug_fields="[\"key\",\"summary\",\"status\",\"assignee\",\"priority\",\"issuetype\",\"fixVersions\",\"components\",\"${CF_STORY_POINTS}\",\"${CF_RELEASE_BLOCKER}\",\"${CF_SFDC_COUNTER}\"]"

  # ── 3 queries (was 7): all_open covers untriaged/unassigned/blockers/escalations
  parallel_init

  parallel_run "all_open" cmd_search \
    "project = OCPBUGS AND ${comp_filter} AND status not in (Closed, Done, Verified) ORDER BY priority ASC, created DESC" 200 "$bug_fields"

  # New bugs this week (includes closed, so can't merge with all_open)
  parallel_run "new_this_week" cmd_search \
    "project = OCPBUGS AND ${comp_filter} AND created >= -7d ORDER BY created DESC" 50

  # Bugs assigned to team members outside ALL Node components
  parallel_run "team_no_component" cmd_search \
    "project = OCPBUGS AND (${assignee_emails}) AND (component is EMPTY OR component not in (${ALL_NODE_COMPONENTS})) AND status not in (Closed, Done, Verified) ORDER BY priority ASC, created DESC" 50

  parallel_wait_all || true

  # ── Assemble results — categorize from all_open in Python ────────────────
  python3 - \
    "$(parallel_get all_open)" \
    "$(parallel_get new_this_week)" \
    "$(parallel_get team_no_component)" \
    "$roster_json" \
    <<'PYEOF'
import json, sys

def extract_bugs(data_str):
    data = json.loads(data_str)
    bugs = []
    for i in data.get("issues", []):
        f = i.get("fields", {})
        components = [c.get("name", "") for c in (f.get("components") or [])]
        rb = f.get("customfield_10847")
        bugs.append({
            "key": i.get("key", ""),
            "summary": f.get("summary", ""),
            "status": f.get("status", {}).get("name", ""),
            "priority": f.get("priority", {}).get("name", ""),
            "assignee": (f.get("assignee") or {}).get("displayName", "Unassigned"),
            "points": f.get("customfield_10028") or 0,
            "releaseBlocker": rb,
            "fixVersions": [v.get("name", "") for v in (f.get("fixVersions") or [])],
            "components": components,
            "sfdcCaseCount": f.get("customfield_10978"),
        })
    return bugs

all_open = extract_bugs(sys.argv[1])
new_this_week = extract_bugs(sys.argv[2])
missing_component = extract_bugs(sys.argv[3])

# Build roster name set for CVE filtering
roster_names = {m["name"] for m in json.loads(sys.argv[4])}

# Filter out CVE bugs that are ASSIGNED to non-roster members (handled by other teams)
def is_external_cve(b):
    return ("CVE" in b["summary"].upper()
            and b["status"] == "ASSIGNED"
            and b["assignee"] not in roster_names
            and b["assignee"] != "Unassigned")

excluded_cves = [b for b in all_open if is_external_cve(b)]
all_open = [b for b in all_open if not is_external_cve(b)]
new_this_week = [b for b in new_this_week if not is_external_cve(b)]
missing_component = [b for b in missing_component if not is_external_cve(b)]

# Shape assertions — warn if field formats have changed
for b in all_open[:5]:  # spot-check first 5
    rb = b.get("releaseBlocker")
    if rb is not None and not isinstance(rb, dict):
        print(f"SHAPE WARNING: releaseBlocker is {type(rb).__name__}, expected dict or None "
              f"(on {b['key']}). Blocker categorization may be broken.", file=sys.stderr)
        break

# Categorize from all_open (was 4 separate JQL queries)
# Bot account is the default assignee — treat as effectively unassigned
BOT_ACCOUNTS = {"Node Team Bot Account"}
untriaged = [b for b in all_open if b["priority"] in ("Undefined", "Unprioritized")]
unassigned = [b for b in all_open if b["assignee"] in ({"Unassigned"} | BOT_ACCOUNTS)]
blocker_proposals = [b for b in all_open
                     if isinstance(b.get("releaseBlocker"), dict)
                     and b["releaseBlocker"].get("value") == "Proposed"]
escalations = [b for b in all_open if b.get("sfdcCaseCount") is not None]

# Canary: if we have bugs but nothing categorized, field formats may have changed
if len(all_open) > 10 and (len(untriaged) + len(unassigned) + len(blocker_proposals) + len(escalations)) == 0:
    print(f"CANARY: {len(all_open)} open bugs but 0 categorized. "
          f"Check releaseBlocker (customfield_10847), sfdcCaseCount (customfield_10978), "
          f"priority values.", file=sys.stderr)

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
        "excludedExternalCVEs": len(excluded_cves),
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

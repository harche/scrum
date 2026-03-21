#!/bin/bash
# Verification harness: compare composite command output vs direct REST API calls
# Usage: bash tests/verify-composites.sh [team]
# Produces a JSON report with pass/fail per composite + per-query comparisons
set -euo pipefail

TEAM="${1:-Node Devices}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

# ── Auth ──────────────────────────────────────────────────────────────────────
JIRA_API_TOKEN=$(security find-generic-password -s "JIRA_API_TOKEN" -w 2>/dev/null)
JIRA_USER=$(security find-generic-password -s "JIRA_API_TOKEN" -g 2>&1 | grep "acct" | sed 's/.*="//;s/"//' 2>/dev/null) || true
[[ -n "$JIRA_USER" && ! "$JIRA_USER" =~ "@" ]] && JIRA_USER="${JIRA_USER}@redhat.com"
[[ -z "$JIRA_USER" ]] && JIRA_USER="${JIRA_EMAIL:-harpatil@redhat.com}"

BASE="https://redhat.atlassian.net"
export JIRA_EMAIL="$JIRA_USER"

TMPDIR_ROOT=$(mktemp -d)
trap "rm -rf '$TMPDIR_ROOT'" EXIT

_log() { echo "[$(date +%H:%M:%S)] $*" >&2; }

# ── Direct API helpers ────────────────────────────────────────────────────────

# Direct curl to REST API (bypasses jira.sh entirely)
_direct_curl() {
  curl -s -u "${JIRA_USER}:${JIRA_API_TOKEN}" -H "Content-Type: application/json" "$@"
}

# Direct JQL search via REST API v3 (new endpoint)
direct_search() {
  local jql="$1"
  local limit="${2:-100}"
  local payload
  payload=$(python3 -c "
import json, sys
print(json.dumps({'jql': sys.argv[1], 'maxResults': int(sys.argv[2]), 'fields': ['summary','status','assignee','priority','issuetype','components','fixVersions']}))
" "$jql" "$limit")
  _direct_curl -X POST "${BASE}/rest/api/3/search/jql" -d "$payload"
}

# Direct sprint issues via Agile API
direct_sprint_issues() {
  local sprint_id="$1"
  local limit="${2:-100}"
  _direct_curl "${BASE}/rest/agile/1.0/sprint/${sprint_id}/issue?maxResults=${limit}&fields=summary,status,assignee,issuetype,priority"
}

# Extract issue keys from search result JSON
extract_keys() {
  python3 -c "
import json, sys
d = json.load(sys.stdin)
keys = sorted([i.get('key','') for i in d.get('issues', [])])
print(json.dumps(keys))
"
}

# Extract count from search result JSON
extract_count() {
  python3 -c "
import json, sys
d = json.load(sys.stdin)
print(len(d.get('issues', [])))
"
}

# Compare two JSON key arrays, return JSON diff
compare_keys() {
  local label="$1" composite_keys="$2" direct_keys="$3"
  python3 -c "
import json, sys
label = sys.argv[1]
ck = set(json.loads(sys.argv[2]))
dk = set(json.loads(sys.argv[3]))
match = ck == dk
only_composite = sorted(ck - dk)
only_direct = sorted(dk - ck)
print(json.dumps({
    'query': label,
    'pass': match,
    'compositeCount': len(ck),
    'directCount': len(dk),
    'onlyInComposite': only_composite,
    'onlyInDirect': only_direct,
}))
" "$label" "$composite_keys" "$direct_keys"
}

# ── Discover sprint ID ────────────────────────────────────────────────────────
_log "Discovering active sprint for: $TEAM"

SPRINT_JSON=$(JIRA_EMAIL="$JIRA_USER" bin/jira.sh sprints active 2>/dev/null)

SPRINT_FILTER=""
case "$TEAM" in
  "Node Devices"|"DRA"|"dra"|"devices") SPRINT_FILTER="Node Devices" ;;
  "Node Core"|"Core"|"core") SPRINT_FILTER="Node Core" ;;
esac

SPRINT_ID=$(echo "$SPRINT_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for s in data.get('values', []):
    if '${SPRINT_FILTER}' in s.get('name', ''):
        print(s['id'])
        break
")

_log "Sprint ID: $SPRINT_ID"

# Resolve team bug components (same as team.sh)
case "$TEAM" in
  "Node Devices"|"DRA"|"dra"|"devices")
    BUG_COMPONENTS='"Node / Device Manager", "Node / Instaslice-operator"'
    ;;
  "Node Core"|"Core"|"core")
    BUG_COMPONENTS='"Node", "Node / CRI-O", "Node / Kubelet", "Node / CPU manager", "Node / Memory manager", "Node / Topology manager", "Node / Numa aware Scheduling", "Node / Device Manager", "Node / Pod resource API", "Node / Node Problem Detector", "Node / Kueue", "Node / Instaslice-operator"'
    ;;
esac

# ── Results collector ─────────────────────────────────────────────────────────
RESULTS_FILE="$TMPDIR_ROOT/results.json"
echo '[]' > "$RESULTS_FILE"

add_result() {
  local cmd_name="$1" test_json="$2"
  python3 -c "
import json, sys
results = json.load(open(sys.argv[1]))
test = json.loads(sys.argv[2])
# Find or create entry for this command
found = False
for r in results:
    if r['command'] == sys.argv[3]:
        r['tests'].append(test)
        found = True
        break
if not found:
    results.append({'command': sys.argv[3], 'tests': [test]})
with open(sys.argv[1], 'w') as f:
    json.dump(results, f)
" "$RESULTS_FILE" "$test_json" "$cmd_name"
}

# ══════════════════════════════════════════════════════════════════════════════
# 1. SPRINT-DASHBOARD
# ══════════════════════════════════════════════════════════════════════════════
_log "Verifying: sprint-dashboard"

composite=$(JIRA_EMAIL="$JIRA_USER" bin/jira.sh sprint-dashboard "$TEAM" 2>/dev/null)
composite_keys=$(echo "$composite" | python3 -c "
import json, sys
d = json.load(sys.stdin)
keys = set()
for group in d.get('byStatus', {}).values():
    for item in group:
        keys.add(item['key'])
print(json.dumps(sorted(keys)))
")

direct=$(direct_sprint_issues "$SPRINT_ID" 100)
direct_keys=$(echo "$direct" | extract_keys)

result=$(compare_keys "sprint-issues (Agile API)" "$composite_keys" "$direct_keys")
add_result "sprint-dashboard" "$result"

sleep 1

# ══════════════════════════════════════════════════════════════════════════════
# 2. BUG-OVERVIEW (7 JQL queries)
# ══════════════════════════════════════════════════════════════════════════════
_log "Verifying: bug-overview"

composite=$(JIRA_EMAIL="$JIRA_USER" bin/jira.sh bug-overview "$TEAM" 2>/dev/null)

# 2a. All open bugs
comp_all_keys=$(echo "$composite" | python3 -c "
import json, sys; d = json.load(sys.stdin)
# allOpen includes merged missing-component bugs
keys = sorted(set(b['key'] for b in d.get('allOpen', [])))
print(json.dumps(keys))
")
direct_all=$(direct_search "project = OCPBUGS AND component in (${BUG_COMPONENTS}) AND status not in (Closed, Done, Verified) ORDER BY priority ASC, created DESC" 100)
direct_all_keys=$(echo "$direct_all" | extract_keys)
result=$(compare_keys "allOpen bugs" "$comp_all_keys" "$direct_all_keys")
add_result "bug-overview" "$result"

sleep 1

# 2b. Untriaged
comp_untriaged=$(echo "$composite" | python3 -c "
import json, sys; print(json.dumps(sorted(b['key'] for b in json.load(sys.stdin).get('untriaged', []))))
")
direct_untriaged=$(direct_search "project = OCPBUGS AND component in (${BUG_COMPONENTS}) AND priority in (Undefined, Unprioritized) AND status not in (Closed, Done, Verified) ORDER BY created DESC" 50)
direct_untriaged_keys=$(echo "$direct_untriaged" | extract_keys)
result=$(compare_keys "untriaged bugs" "$comp_untriaged" "$direct_untriaged_keys")
add_result "bug-overview" "$result"

sleep 1

# 2c. Unassigned
comp_unassigned=$(echo "$composite" | python3 -c "
import json, sys; print(json.dumps(sorted(b['key'] for b in json.load(sys.stdin).get('unassigned', []))))
")
direct_unassigned=$(direct_search "project = OCPBUGS AND component in (${BUG_COMPONENTS}) AND assignee is EMPTY AND status not in (Closed, Done, Verified) ORDER BY priority ASC, created DESC" 50)
direct_unassigned_keys=$(echo "$direct_unassigned" | extract_keys)
result=$(compare_keys "unassigned bugs" "$comp_unassigned" "$direct_unassigned_keys")
add_result "bug-overview" "$result"

sleep 1

# 2d. Blocker proposals
comp_blockers=$(echo "$composite" | python3 -c "
import json, sys; print(json.dumps(sorted(b['key'] for b in json.load(sys.stdin).get('blockerProposals', []))))
")
direct_blockers=$(direct_search "project = OCPBUGS AND component in (${BUG_COMPONENTS}) AND \"Release Blocker\" = \"Proposed\" AND status not in (Closed, Done, Verified) ORDER BY priority ASC" 50)
direct_blockers_keys=$(echo "$direct_blockers" | extract_keys)
result=$(compare_keys "blocker proposals" "$comp_blockers" "$direct_blockers_keys")
add_result "bug-overview" "$result"

sleep 1

# 2e. Customer escalations
comp_escalations=$(echo "$composite" | python3 -c "
import json, sys; print(json.dumps(sorted(b['key'] for b in json.load(sys.stdin).get('customerEscalations', []))))
")
direct_escalations=$(direct_search "project = OCPBUGS AND component in (${BUG_COMPONENTS}) AND \"SFDC Cases Counter\" is not EMPTY AND status not in (Closed, Done, Verified) ORDER BY priority ASC" 50)
direct_escalations_keys=$(echo "$direct_escalations" | extract_keys)
result=$(compare_keys "customer escalations" "$comp_escalations" "$direct_escalations_keys")
add_result "bug-overview" "$result"

sleep 1

# 2f. New this week
comp_new=$(echo "$composite" | python3 -c "
import json, sys; print(json.dumps(sorted(b['key'] for b in json.load(sys.stdin).get('newThisWeek', []))))
")
direct_new=$(direct_search "project = OCPBUGS AND component in (${BUG_COMPONENTS}) AND created >= -7d ORDER BY created DESC" 50)
direct_new_keys=$(echo "$direct_new" | extract_keys)
result=$(compare_keys "new this week" "$comp_new" "$direct_new_keys")
add_result "bug-overview" "$result"

sleep 1

# ══════════════════════════════════════════════════════════════════════════════
# 3. CARRYOVER-REPORT
# ══════════════════════════════════════════════════════════════════════════════
_log "Verifying: carryover-report"

composite=$(JIRA_EMAIL="$JIRA_USER" bin/jira.sh carryover-report "$TEAM" 2>/dev/null)
comp_total=$(echo "$composite" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['totalItems'])")
comp_done=$(echo "$composite" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['doneCount'])")
comp_carry=$(echo "$composite" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['carryoverCount'])")

# Uses same sprint issues — verify total = done + carryover
result=$(python3 -c "
import json
total = int('$comp_total')
done = int('$comp_done')
carry = int('$comp_carry')
match = total == done + carry
print(json.dumps({
    'query': 'total = done + carryovers',
    'pass': match,
    'compositeCount': total,
    'directCount': done + carry,
    'onlyInComposite': [],
    'onlyInDirect': ['total={}, done={}, carry={}'.format(total, done, carry)] if not match else [],
}))
")
add_result "carryover-report" "$result"

# Cross-check total against direct sprint issues
direct=$(direct_sprint_issues "$SPRINT_ID" 100)
direct_count=$(echo "$direct" | extract_count)
result=$(python3 -c "
import json
print(json.dumps({
    'query': 'sprint-issues total count',
    'pass': int('$comp_total') == int('$direct_count'),
    'compositeCount': int('$comp_total'),
    'directCount': int('$direct_count'),
    'onlyInComposite': [],
    'onlyInDirect': [],
}))
")
add_result "carryover-report" "$result"

sleep 1

# ══════════════════════════════════════════════════════════════════════════════
# 4. PLANNING-DATA
# ══════════════════════════════════════════════════════════════════════════════
_log "Verifying: planning-data"

composite=$(JIRA_EMAIL="$JIRA_USER" bin/jira.sh planning-data "$TEAM" 2>/dev/null)

# 4a. Backlog candidates
comp_backlog=$(echo "$composite" | python3 -c "
import json, sys; print(json.dumps(sorted(b['key'] for b in json.load(sys.stdin).get('backlogCandidates', []))))
")
direct_backlog=$(direct_search "project = OCPNODE AND sprint is EMPTY AND status not in (Closed, Done) AND type in (Story, Task, Spike) ORDER BY priority ASC, created DESC" 30)
direct_backlog_keys=$(echo "$direct_backlog" | extract_keys)
result=$(compare_keys "backlog candidates" "$comp_backlog" "$direct_backlog_keys")
add_result "planning-data" "$result"

sleep 1

# 4b. Unscheduled bugs
comp_unsched=$(echo "$composite" | python3 -c "
import json, sys; print(json.dumps(sorted(b['key'] for b in json.load(sys.stdin).get('unscheduledBugs', []))))
")
direct_unsched=$(direct_search "project = OCPBUGS AND component in (${BUG_COMPONENTS}) AND sprint is EMPTY AND status not in (Closed, Done, Verified) ORDER BY priority ASC, created DESC" 30)
direct_unsched_keys=$(echo "$direct_unsched" | extract_keys)
result=$(compare_keys "unscheduled bugs" "$comp_unsched" "$direct_unsched_keys")
add_result "planning-data" "$result"

sleep 1

# ══════════════════════════════════════════════════════════════════════════════
# 5. RELEASE-DATA
# ══════════════════════════════════════════════════════════════════════════════
_log "Verifying: release-data"

composite=$(JIRA_EMAIL="$JIRA_USER" bin/jira.sh release-data "$TEAM" 2>/dev/null)
version=$(echo "$composite" | python3 -c "import json,sys; print(json.load(sys.stdin)['version'])")

# 5a. Approved blockers
comp_ab=$(echo "$composite" | python3 -c "
import json, sys; print(json.dumps(sorted(b['key'] for b in json.load(sys.stdin).get('approvedBlockers', []))))
")
direct_ab=$(direct_search "project = OCPBUGS AND component in (${BUG_COMPONENTS}) AND \"Release Blocker\" = \"Approved\" AND fixVersion = \"${version}\" AND status not in (Closed, Done, Verified) ORDER BY priority ASC" 50)
direct_ab_keys=$(echo "$direct_ab" | extract_keys)
result=$(compare_keys "approved blockers" "$comp_ab" "$direct_ab_keys")
add_result "release-data" "$result"

sleep 1

# 5b. Open bugs for version
comp_ob=$(echo "$composite" | python3 -c "
import json, sys; print(json.dumps(sorted(b['key'] for b in json.load(sys.stdin).get('openBugs', []))))
")
direct_ob=$(direct_search "project = OCPBUGS AND component in (${BUG_COMPONENTS}) AND fixVersion = \"${version}\" AND status not in (Closed, Done, Verified) ORDER BY priority ASC" 50)
direct_ob_keys=$(echo "$direct_ob" | extract_keys)
result=$(compare_keys "open bugs for version" "$comp_ob" "$direct_ob_keys")
add_result "release-data" "$result"

sleep 1

# 5c. Epics for version (now team-filtered)
comp_ep=$(echo "$composite" | python3 -c "
import json, sys; print(json.dumps(sorted(b['key'] for b in json.load(sys.stdin).get('epics', []))))
")
direct_ep=$(direct_search "project = OCPNODE AND issuetype = Epic AND component in (${BUG_COMPONENTS}) AND fixVersion = \"${version}\" ORDER BY status ASC" 50)
direct_ep_keys=$(echo "$direct_ep" | extract_keys)
result=$(compare_keys "epics for version (team-filtered)" "$comp_ep" "$direct_ep_keys")
add_result "release-data" "$result"

sleep 1

# ══════════════════════════════════════════════════════════════════════════════
# 6. PICKUP-DATA
# ══════════════════════════════════════════════════════════════════════════════
_log "Verifying: pickup-data"

composite=$(JIRA_EMAIL="$JIRA_USER" bin/jira.sh pickup-data "$TEAM" 2>/dev/null)

# 6a. Unassigned bugs
comp_ub=$(echo "$composite" | python3 -c "
import json, sys; print(json.dumps(sorted(b['key'] for b in json.load(sys.stdin).get('unassignedBugs', []))))
")
direct_ub=$(direct_search "project = OCPBUGS AND component in (${BUG_COMPONENTS}) AND assignee is EMPTY AND status not in (CLOSED, Verified, Done) ORDER BY priority ASC, created ASC" 50)
direct_ub_keys=$(echo "$direct_ub" | extract_keys)
result=$(compare_keys "unassigned bugs (pickup)" "$comp_ub" "$direct_ub_keys")
add_result "pickup-data" "$result"

sleep 1

# 6b. Customer escalations (unassigned)
comp_esc=$(echo "$composite" | python3 -c "
import json, sys; print(json.dumps(sorted(b['key'] for b in json.load(sys.stdin).get('customerEscalations', []))))
")
direct_esc=$(direct_search "project = OCPBUGS AND component in (${BUG_COMPONENTS}) AND assignee is EMPTY AND \"SFDC Cases Counter\" is not EMPTY AND status not in (CLOSED, Verified, Done)" 50)
direct_esc_keys=$(echo "$direct_esc" | extract_keys)
result=$(compare_keys "customer escalations (pickup)" "$comp_esc" "$direct_esc_keys")
add_result "pickup-data" "$result"

sleep 1

# ══════════════════════════════════════════════════════════════════════════════
# 7. MY-BUGS-DATA
# ══════════════════════════════════════════════════════════════════════════════
_log "Verifying: my-bugs-data"

composite=$(JIRA_EMAIL="$JIRA_USER" bin/jira.sh my-bugs-data "$TEAM" 2>/dev/null)

comp_mb=$(echo "$composite" | python3 -c "
import json, sys; print(json.dumps(sorted(b['key'] for b in json.load(sys.stdin).get('allBugs', []))))
")
direct_mb=$(direct_search "project = OCPBUGS AND component in (${BUG_COMPONENTS}) AND assignee = \"${JIRA_USER}\" AND status not in (CLOSED, Verified, Done) ORDER BY priority ASC, created ASC" 100)
direct_mb_keys=$(echo "$direct_mb" | extract_keys)
result=$(compare_keys "my bugs" "$comp_mb" "$direct_mb_keys")
add_result "my-bugs-data" "$result"

sleep 1

# ══════════════════════════════════════════════════════════════════════════════
# 8. MY-BOARD-DATA
# ══════════════════════════════════════════════════════════════════════════════
_log "Verifying: my-board-data"

composite=$(JIRA_EMAIL="$JIRA_USER" bin/jira.sh my-board-data "$TEAM" 2>/dev/null)

# My board filters sprint issues to current user — verify sprint total and user total
comp_my_total=$(echo "$composite" | python3 -c "import json,sys; print(json.load(sys.stdin)['summary']['total'])")

# Direct: get all sprint issues, filter to user
direct=$(direct_sprint_issues "$SPRINT_ID" 100)
direct_my_count=$(echo "$direct" | python3 -c "
import json, sys
user = '$JIRA_USER'
d = json.load(sys.stdin)
count = 0
for i in d.get('issues', []):
    a = (i.get('fields', {}).get('assignee') or {})
    if a.get('emailAddress', '') == user or a.get('displayName', '') == user:
        count += 1
print(count)
")
result=$(python3 -c "
import json
print(json.dumps({
    'query': 'my sprint items (filtered)',
    'pass': int('$comp_my_total') == int('$direct_my_count'),
    'compositeCount': int('$comp_my_total'),
    'directCount': int('$direct_my_count'),
    'onlyInComposite': [],
    'onlyInDirect': [],
}))
")
add_result "my-board-data" "$result"

sleep 1

# ══════════════════════════════════════════════════════════════════════════════
# 9. STANDUP-DATA
# ══════════════════════════════════════════════════════════════════════════════
_log "Verifying: standup-data"

composite=$(JIRA_EMAIL="$JIRA_USER" bin/jira.sh standup-data "$TEAM" 2>/dev/null)

# 9a. Sprint issues total
comp_total=$(echo "$composite" | python3 -c "import json,sys; print(json.load(sys.stdin)['summary']['total'])")
direct=$(direct_sprint_issues "$SPRINT_ID" 100)
direct_count=$(echo "$direct" | extract_count)
result=$(python3 -c "
import json
print(json.dumps({
    'query': 'sprint issues total',
    'pass': int('$comp_total') == int('$direct_count'),
    'compositeCount': int('$comp_total'),
    'directCount': int('$direct_count'),
    'onlyInComposite': [],
    'onlyInDirect': [],
}))
")
add_result "standup-data" "$result"

sleep 1

# 9b. New bugs
comp_bugs=$(echo "$composite" | python3 -c "
import json, sys; print(json.dumps(sorted(b['key'] for b in json.load(sys.stdin).get('newBugs', []))))
")
direct_bugs=$(direct_search "project = OCPBUGS AND component in (${BUG_COMPONENTS}) AND created >= -7d ORDER BY created DESC" 50)
direct_bugs_keys=$(echo "$direct_bugs" | extract_keys)
result=$(compare_keys "new bugs (7d)" "$comp_bugs" "$direct_bugs_keys")
add_result "standup-data" "$result"

sleep 1

# ══════════════════════════════════════════════════════════════════════════════
# 10. ISSUE-DEEP-DIVE (use a known issue from the sprint)
# ══════════════════════════════════════════════════════════════════════════════
_log "Verifying: issue-deep-dive"

# Pick first issue from sprint for testing
test_key=$(echo "$direct" | python3 -c "
import json, sys
d = json.load(sys.stdin)
issues = d.get('issues', [])
if issues:
    print(issues[0]['key'])
else:
    print('')
")

if [[ -n "$test_key" ]]; then
  composite=$(JIRA_EMAIL="$JIRA_USER" bin/jira.sh issue-deep-dive "$test_key" 2>/dev/null)

  # Verify key, summary, status match direct GET
  direct_issue=$(_direct_curl "${BASE}/rest/api/3/issue/${test_key}?fields=summary,status,assignee,priority")
  result=$(python3 -c "
import json, sys
comp = json.loads(sys.argv[1])
direct = json.loads(sys.argv[2])
df = direct.get('fields', {})
checks = {
    'key': comp.get('key', '') == direct.get('key', ''),
    'summary': comp.get('summary', '') == df.get('summary', ''),
    'status': comp.get('status', '') == df.get('status', {}).get('name', ''),
}
all_pass = all(checks.values())
failures = [k for k, v in checks.items() if not v]
print(json.dumps({
    'query': f'issue fields ({direct.get(\"key\",\"\")})',
    'pass': all_pass,
    'compositeCount': 1,
    'directCount': 1,
    'onlyInComposite': [],
    'onlyInDirect': failures,
}))
" "$composite" "$direct_issue")
  add_result "issue-deep-dive" "$result"

  sleep 1

  # Verify transitions match
  direct_transitions=$(_direct_curl "${BASE}/rest/api/3/issue/${test_key}/transitions")
  result=$(python3 -c "
import json, sys
comp = json.loads(sys.argv[1])
direct = json.loads(sys.argv[2])
comp_names = sorted([t['name'] for t in comp.get('transitions', [])])
direct_names = sorted([t['name'] for t in direct.get('transitions', [])])
print(json.dumps({
    'query': f'transitions ({sys.argv[3]})',
    'pass': comp_names == direct_names,
    'compositeCount': len(comp_names),
    'directCount': len(direct_names),
    'onlyInComposite': sorted(set(comp_names) - set(direct_names)),
    'onlyInDirect': sorted(set(direct_names) - set(comp_names)),
}))
" "$composite" "$direct_transitions" "$test_key")
  add_result "issue-deep-dive" "$result"

  sleep 1

  # Verify comments count
  direct_comments=$(_direct_curl "${BASE}/rest/api/3/issue/${test_key}/comment")
  result=$(python3 -c "
import json, sys
comp = json.loads(sys.argv[1])
direct = json.loads(sys.argv[2])
comp_count = len(comp.get('comments', []))
direct_count = len(direct.get('comments', []))
print(json.dumps({
    'query': f'comments count ({sys.argv[3]})',
    'pass': comp_count == direct_count,
    'compositeCount': comp_count,
    'directCount': direct_count,
    'onlyInComposite': [],
    'onlyInDirect': [],
}))
" "$composite" "$direct_comments" "$test_key")
  add_result "issue-deep-dive" "$result"
fi

sleep 1

# ══════════════════════════════════════════════════════════════════════════════
# 11. EPIC-PROGRESS
# ══════════════════════════════════════════════════════════════════════════════
_log "Verifying: epic-progress"

composite=$(JIRA_EMAIL="$JIRA_USER" bin/jira.sh epic-progress "$TEAM" 2>/dev/null)

comp_epic_count=$(echo "$composite" | python3 -c "import json,sys; print(json.load(sys.stdin)['summary']['totalEpics'])")

# Verify by checking which sprint items assigned to me have epic links
direct=$(direct_sprint_issues "$SPRINT_ID" 100)
direct_epic_count=$(python3 -c "
import json, sys
d = json.loads(sys.argv[1])
user = sys.argv[2]
epics = set()
for i in d.get('issues', []):
    f = i.get('fields', {})
    a = f.get('assignee') or {}
    if a.get('emailAddress', '') == user or a.get('displayName', '') == user:
        ek = f.get('customfield_10014')
        if ek:
            epics.add(ek)
print(len(epics))
" "$direct" "$JIRA_USER")

result=$(python3 -c "
import json
print(json.dumps({
    'query': 'epic count for current user',
    'pass': int('$comp_epic_count') == int('$direct_epic_count'),
    'compositeCount': int('$comp_epic_count'),
    'directCount': int('$direct_epic_count'),
    'onlyInComposite': [],
    'onlyInDirect': [],
}))
")
add_result "epic-progress" "$result"

# Note: epic-progress uses sprint-issues which doesn't return customfield_10014
# unless it's in the fields list — but the Agile API may not support it.
# The composite uses cmd_sprint_issues which includes CF_EPIC_LINK in ISSUE_FIELDS.

sleep 1

# ══════════════════════════════════════════════════════════════════════════════
# 12. TEAM-ACTIVITY
# ══════════════════════════════════════════════════════════════════════════════
_log "Verifying: team-activity"

composite=$(JIRA_EMAIL="$JIRA_USER" bin/jira.sh team-activity "$TEAM" 2>/dev/null)

# Verify total sprint items across all members
comp_ta_total=$(echo "$composite" | python3 -c "
import json, sys
d = json.load(sys.stdin)
total = sum(m.get('sprintItemCount', 0) for m in d.get('members', []))
print(total)
")
direct=$(direct_sprint_issues "$SPRINT_ID" 100)
# Count assigned items (excluding Unassigned)
direct_ta_total=$(echo "$direct" | python3 -c "
import json, sys
d = json.load(sys.stdin)
count = sum(1 for i in d.get('issues', []) if (i.get('fields',{}).get('assignee') or {}).get('displayName','') != '')
print(count)
")
result=$(python3 -c "
import json
print(json.dumps({
    'query': 'total assigned sprint items',
    'pass': int('$comp_ta_total') == int('$direct_ta_total'),
    'compositeCount': int('$comp_ta_total'),
    'directCount': int('$direct_ta_total'),
    'onlyInComposite': [],
    'onlyInDirect': [],
}))
")
add_result "team-activity" "$result"

sleep 1

# ══════════════════════════════════════════════════════════════════════════════
# 13. MY-STANDUP-DATA
# ══════════════════════════════════════════════════════════════════════════════
_log "Verifying: my-standup-data"

composite=$(JIRA_EMAIL="$JIRA_USER" bin/jira.sh my-standup-data "$TEAM" 2>/dev/null)

comp_my_total=$(echo "$composite" | python3 -c "
import json, sys
d = json.load(sys.stdin)
s = d.get('summary', {})
print(s.get('done',0) + s.get('inProgress',0) + s.get('blocked',0) + s.get('toDo',0))
")
# Cross-check against my-board-data total (both filter sprint issues to current user)
my_board=$(JIRA_EMAIL="$JIRA_USER" bin/jira.sh my-board-data "$TEAM" 2>/dev/null)
board_total=$(echo "$my_board" | python3 -c "import json,sys; print(json.load(sys.stdin)['summary']['total'])")
result=$(python3 -c "
import json
print(json.dumps({
    'query': 'my items total (vs my-board-data)',
    'pass': int('$comp_my_total') == int('$board_total'),
    'compositeCount': int('$comp_my_total'),
    'directCount': int('$board_total'),
    'onlyInComposite': [],
    'onlyInDirect': [],
}))
")
add_result "my-standup-data" "$result"

# ══════════════════════════════════════════════════════════════════════════════
# FINAL REPORT
# ══════════════════════════════════════════════════════════════════════════════
_log "Verification complete"

python3 -c "
import json, sys

results = json.load(open(sys.argv[1]))

total_tests = 0
total_pass = 0
total_fail = 0
failures = []

for cmd in results:
    for t in cmd['tests']:
        total_tests += 1
        if t['pass']:
            total_pass += 1
        else:
            total_fail += 1
            failures.append({'command': cmd['command'], 'test': t})

report = {
    'team': sys.argv[2],
    'totalTests': total_tests,
    'passed': total_pass,
    'failed': total_fail,
    'commands': results,
    'failures': failures,
}

print(json.dumps(report, indent=2))
" "$RESULTS_FILE" "$TEAM"

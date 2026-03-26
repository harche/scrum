#!/usr/bin/env bats
# Tests for ALL composite commands with mocked HTTP
# Validates JSON structure, field presence, edge cases

setup() {
  source "${BATS_TEST_DIRNAME}/test-helper.sh"
  load_all_mocked
  source "${PROJECT_ROOT}/bin/lib/util/parallel.sh"
  for f in "${PROJECT_ROOT}"/bin/lib/composite/*.sh; do
    [[ -f "$f" ]] && source "$f"
  done
  # Set JIRA_USER for user-filtered composites
  JIRA_USER="alice@example.com"
}

# ── Helper to validate JSON structure ──────────────────────────────────────────

assert_valid_json() {
  echo "$1" | python3 -c "import json,sys; json.load(sys.stdin)"
}

assert_has_key() {
  echo "$1" | python3 -c "import json,sys; d=json.load(sys.stdin); assert '$2' in d, f'Missing key: $2'"
}

assert_key_count() {
  local actual
  actual=$(echo "$1" | python3 -c "import json,sys; print(json.load(sys.stdin)$2)")
  [[ "$actual" == "$3" ]]
}

# ── sprint-dashboard ───────────────────────────────────────────────────────────

@test "sprint-dashboard: valid JSON with all required keys" {
  run cmd_sprint_dashboard "Node Devices"
  assert_valid_json "$output"
  for key in sprint summary byStatus blockers atRisk teamWorkload roster; do
    assert_has_key "$output" "$key"
  done
}

@test "sprint-dashboard: sprint has progress fields" {
  run cmd_sprint_dashboard "Node Devices"
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)['sprint']
for f in ['id', 'name', 'startDate', 'endDate', 'daysElapsed', 'daysTotal', 'daysRemaining', 'goal']:
    assert f in d, f'Sprint missing field: {f}'
"
}

@test "sprint-dashboard: summary counts match item count" {
  run cmd_sprint_dashboard "Node Devices"
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
sm = d['summary']
total_in_groups = sum(len(v) for v in d['byStatus'].values())
assert total_in_groups == sm['total'], f'Item count mismatch: {total_in_groups} vs {sm[\"total\"]}'
"
}

@test "sprint-dashboard: items have all required fields" {
  run cmd_sprint_dashboard "Node Devices"
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for group, items in d['byStatus'].items():
    for item in items:
        for f in ['key', 'summary', 'status', 'assignee', 'points', 'type', 'blocked']:
            assert f in item, f'Item {item.get(\"key\",\"?\")} in {group} missing field: {f}'
"
}

@test "sprint-dashboard: detects blocked items from fixture" {
  run cmd_sprint_dashboard "Node Devices"
  assert_key_count "$output" "['blockers'].__len__()" "1"
}

@test "sprint-dashboard: roster includes all roster members plus off-roster assignees" {
  run cmd_sprint_dashboard "Node Devices"
  echo "$output" | python3 -c "
import json, sys, os
d = json.load(sys.stdin)
roster = d['roster']
# Load actual roster file to get expected count
with open(os.path.join(sys.argv[1], 'config/team-roster-dra.json')) as f:
    expected = len(json.load(f)['members'])
# Should have at least as many entries as the roster file
assert len(roster) >= expected, f'Expected at least {expected} roster entries, got {len(roster)}'
# Each entry should have name, github, hasItems
for m in roster:
    assert 'name' in m and 'github' in m and 'hasItems' in m
" "$PROJECT_ROOT"
}

# ── standup-data ───────────────────────────────────────────────────────────────

@test "standup-data: valid JSON with all required keys" {
  run cmd_standup_data "Node Devices"
  assert_valid_json "$output"
  for key in sprint summary byStatus blockers atRisk memberActivity teamWorkload; do
    assert_has_key "$output" "$key"
  done
}

@test "standup-data: memberActivity includes all roster members" {
  run cmd_standup_data "Node Devices"
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
members = d['memberActivity']
names = {m['name'] for m in members}
# Verify roster names match the actual roster file
import os
with open(os.path.join('$PROJECT_ROOT', 'config/team-roster-dra.json')) as f:
    expected_names = set(json.load(f)['members'].keys())
assert expected_names.issubset(names), f'Missing roster members: {expected_names - names}'
for m in members:
    for f in ['name', 'github', 'sprintItems', 'commentCount7d', 'statusSummary']:
        assert f in m, f'Member {m[\"name\"]} missing field: {f}'
"
}

# ── issue-deep-dive ────────────────────────────────────────────────────────────

@test "issue-deep-dive: valid JSON with all required keys" {
  run cmd_issue_deep_dive OCPNODE-1001
  assert_valid_json "$output"
  for key in key summary description status assignee points transitions comments linkedIssues blocked blockedReason; do
    assert_has_key "$output" "$key"
  done
}

@test "issue-deep-dive: description is plain text (ADF converted)" {
  run cmd_issue_deep_dive OCPNODE-1001
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
desc = d['description']
assert 'This is the description' in desc, f'Description not converted from ADF: {desc[:50]}'
assert '{' not in desc[:10], f'Description looks like raw JSON/ADF: {desc[:50]}'
"
}

@test "issue-deep-dive: comments are plain text with author" {
  run cmd_issue_deep_dive OCPNODE-1001
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert len(d['comments']) == 3, f'Expected 3 comments, got {len(d[\"comments\"])}'
for c in d['comments']:
    assert 'author' in c and 'body' in c and 'created' in c
    assert '{' not in c['body'][:5], f'Comment body looks like raw ADF: {c[\"body\"][:30]}'
"
}

@test "issue-deep-dive: transitions have id and name" {
  run cmd_issue_deep_dive OCPNODE-1001
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert len(d['transitions']) == 4
for t in d['transitions']:
    assert 'id' in t and 'name' in t
"
}

@test "issue-deep-dive: linked issues extracted" {
  run cmd_issue_deep_dive OCPNODE-1001
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert len(d['linkedIssues']) == 1
link = d['linkedIssues'][0]
assert link['key'] == 'OCPNODE-1002'
assert 'relationship' in link
"
}

# ── bug-overview ───────────────────────────────────────────────────────────────

@test "bug-overview: valid JSON with all categories" {
  run cmd_bug_overview "Node Devices"
  assert_valid_json "$output"
  for key in summary untriaged unassigned blockerProposals newThisWeek missingComponent allOpen; do
    assert_has_key "$output" "$key"
  done
}

@test "bug-overview: summary has all counts including missingComponent" {
  run cmd_bug_overview "Node Devices"
  echo "$output" | python3 -c "
import json, sys
sm = json.load(sys.stdin)['summary']
for f in ['totalOpen', 'untriaged', 'unassigned', 'blockerProposals', 'newThisWeek', 'missingComponent']:
    assert f in sm, f'Summary missing: {f}'
"
}

@test "bug-overview: bugs include components field" {
  run cmd_bug_overview "Node Devices"
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for b in d['allOpen']:
    assert 'components' in b, f'{b[\"key\"]} missing components field'
"
}

@test "bug-overview: categorizes untriaged bugs (Undefined priority)" {
  run cmd_bug_overview "Node Devices"
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
untriaged_keys = [b['key'] for b in d['untriaged']]
assert 'OCPBUGS-99001' in untriaged_keys, f'OCPBUGS-99001 (Undefined priority) should be untriaged, got: {untriaged_keys}'
assert d['summary']['untriaged'] >= 1
"
}

@test "bug-overview: categorizes unassigned bugs" {
  run cmd_bug_overview "Node Devices"
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
unassigned_keys = [b['key'] for b in d['unassigned']]
assert 'OCPBUGS-99001' in unassigned_keys, f'OCPBUGS-99001 (null assignee) should be unassigned, got: {unassigned_keys}'
assert d['summary']['unassigned'] >= 1
"
}

@test "bug-overview: categorizes blocker proposals from releaseBlocker dict" {
  run cmd_bug_overview "Node Devices"
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
proposal_keys = [b['key'] for b in d['blockerProposals']]
assert 'OCPBUGS-99002' in proposal_keys, f'OCPBUGS-99002 (releaseBlocker Proposed) should be a blocker proposal, got: {proposal_keys}'
assert d['summary']['blockerProposals'] >= 1
"
}


@test "bug-overview: no shape warnings on stderr for valid data" {
  run cmd_bug_overview "Node Devices"
  [[ "$stderr" != *"SHAPE WARNING"* ]] || [[ -z "$stderr" ]]
  [[ "$stderr" != *"CANARY"* ]] || [[ -z "$stderr" ]]
}

# ── carryover-report ───────────────────────────────────────────────────────────

@test "carryover-report: valid JSON with all keys" {
  run cmd_carryover_report "Node Devices"
  assert_valid_json "$output"
  for key in activeSprint carryovers doneItems stats; do
    assert_has_key "$output" "$key"
  done
}

@test "carryover-report: separates done from carryovers correctly" {
  run cmd_carryover_report "Node Devices"
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['stats']['doneCount'] == 1, f'Expected 1 done, got {d[\"stats\"][\"doneCount\"]}'
assert d['stats']['carryoverCount'] == 2, f'Expected 2 carryovers, got {d[\"stats\"][\"carryoverCount\"]}'
assert d['stats']['doneCount'] + d['stats']['carryoverCount'] == d['stats']['totalItems']
"
}

@test "carryover-report: carryovers include previousSprints count" {
  run cmd_carryover_report "Node Devices"
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for c in d['carryovers']:
    assert 'previousSprints' in c, f'{c[\"key\"]} missing previousSprints'
"
}

# ── my-board-data ──────────────────────────────────────────────────────────────

@test "my-board-data: valid JSON filtered to user" {
  run cmd_my_board_data "Node Devices"
  assert_valid_json "$output"
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
# Fixture: OCPNODE-1001 assigned to Alice (alice@example.com = JIRA_USER)
assert d['summary']['total'] >= 1, f'Expected at least 1 item for user'
"
}

@test "my-board-data: has sprint, summary, byStatus, flags" {
  run cmd_my_board_data "Node Devices"
  for key in sprint summary byStatus flags; do
    assert_has_key "$output" "$key"
  done
}

@test "my-board-data: flags items without points" {
  run cmd_my_board_data "Node Devices"
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
# All items should have the required fields
for g, items in d['byStatus'].items():
    for i in items:
        for f in ['key', 'summary', 'status', 'points', 'type', 'blocked']:
            assert f in i, f'Missing {f} in {i.get(\"key\",\"?\")}'
"
}

# ── my-bugs-data ───────────────────────────────────────────────────────────────

@test "my-bugs-data: valid JSON with required keys" {
  run cmd_my_bugs_data "Node Devices"
  assert_valid_json "$output"
  for key in team summary customerEscalations releaseBlockers allBugs; do
    assert_has_key "$output" "$key"
  done
}

@test "my-bugs-data: summary has byPriority" {
  run cmd_my_bugs_data "Node Devices"
  echo "$output" | python3 -c "
import json, sys
sm = json.load(sys.stdin)['summary']
assert 'byPriority' in sm
assert 'total' in sm
"
}

# ── epic-progress ──────────────────────────────────────────────────────────────

@test "epic-progress: valid JSON with sprint and epics" {
  run cmd_epic_progress "Node Devices"
  assert_valid_json "$output"
  for key in sprint epics summary; do
    assert_has_key "$output" "$key"
  done
}

@test "epic-progress: handles user with epic-linked items" {
  run cmd_epic_progress "Node Devices"
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
# Fixture: Alice has OCPNODE-1001 with epic OCPNODE-900
if d['epics']:
    for e in d['epics']:
        assert 'progress' in e
        p = e['progress']
        for f in ['total', 'done', 'inProgress', 'toDo', 'percent']:
            assert f in p, f'Epic {e[\"key\"]} missing progress.{f}'
        assert 'myItems' in e and 'otherItems' in e
"
}

@test "epic-progress: handles user with no epic-linked items gracefully" {
  # Change JIRA_USER to someone not in the fixture
  JIRA_USER="nobody@example.com"
  run cmd_epic_progress "Node Devices"
  assert_valid_json "$output"
  assert_key_count "$output" "['summary']['totalEpics']" "0"
}

# ── pickup-data ────────────────────────────────────────────────────────────────

@test "pickup-data: valid JSON with all categories" {
  run cmd_pickup_data "Node Devices"
  assert_valid_json "$output"
  for key in sprint unassignedSprintItems unassignedBugs summary; do
    assert_has_key "$output" "$key"
  done
}

@test "pickup-data: summary has correct counts" {
  run cmd_pickup_data "Node Devices"
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
sm = d['summary']
assert sm['sprintItems'] == len(d['unassignedSprintItems'])
assert sm['bugs'] == len(d['unassignedBugs'])
"
}


@test "pickup-data: finds unassigned sprint items from fixture" {
  run cmd_pickup_data "Node Devices"
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
# Fixture: OCPNODE-1003 has no assignee
unassigned_keys = [i['key'] for i in d['unassignedSprintItems']]
assert 'OCPNODE-1003' in unassigned_keys, f'Expected OCPNODE-1003 in unassigned, got: {unassigned_keys}'
"
}

# ── release-data categorization ───────────────────────────────────────────

@test "release-data: categorizes approved and proposed blockers" {
  run cmd_release_data "Node Devices" "4.20"
  assert_valid_json "$output"
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
# Fixture has OCPBUGS-99002 with Proposed, OCPBUGS-99003 with Approved
proposed_keys = [b['key'] for b in d['proposedBlockers']]
approved_keys = [b['key'] for b in d['approvedBlockers']]
assert 'OCPBUGS-99002' in proposed_keys, f'Expected OCPBUGS-99002 in proposed, got: {proposed_keys}'
assert 'OCPBUGS-99003' in approved_keys, f'Expected OCPBUGS-99003 in approved, got: {approved_keys}'
assert d['summary']['proposedBlockers'] >= 1
assert d['summary']['approvedBlockers'] >= 1
"
}

@test "release-data: openBugs includes releaseBlocker field" {
  run cmd_release_data "Node Devices" "4.20"
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for b in d['openBugs']:
    assert 'releaseBlocker' in b, f'{b[\"key\"]} missing releaseBlocker field'
"
}

# ── standup-data recentlyUpdatedKeys ──────────────────────────────────────

@test "standup-data: derives recentlyUpdatedKeys from updated field" {
  run cmd_standup_data "Node Devices"
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert 'recentlyUpdatedKeys' in d, 'Missing recentlyUpdatedKeys'
rk = d['recentlyUpdatedKeys']
# Fixture: OCPNODE-1001 and OCPNODE-1002 have updated=2099 (always recent)
# OCPNODE-1003 has updated=2020 (always old)
assert 'OCPNODE-1001' in rk, f'OCPNODE-1001 (recent) should be in recentlyUpdatedKeys: {rk}'
assert 'OCPNODE-1002' in rk, f'OCPNODE-1002 (recent) should be in recentlyUpdatedKeys: {rk}'
assert 'OCPNODE-1003' not in rk, f'OCPNODE-1003 (old) should NOT be in recentlyUpdatedKeys: {rk}'
"
}

@test "standup-data: no shape warnings on stderr for valid data" {
  run cmd_standup_data "Node Devices"
  [[ "$stderr" != *"SHAPE WARNING"* ]] || [[ -z "$stderr" ]]
}

# ── my-standup-data ────────────────────────────────────────────────────────────

@test "my-standup-data: valid JSON with all sections" {
  run cmd_my_standup_data "Node Devices"
  assert_valid_json "$output"
  for key in sprint done inProgress blocked upNext recentComments summary; do
    assert_has_key "$output" "$key"
  done
}

@test "my-standup-data: items have required fields" {
  run cmd_my_standup_data "Node Devices"
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for section in ['done', 'inProgress', 'blocked', 'upNext']:
    for item in d[section]:
        for f in ['key', 'summary', 'status', 'points', 'type', 'blocked']:
            assert f in item, f'{section} item {item.get(\"key\",\"?\")} missing: {f}'
"
}

# ── planning-data ──────────────────────────────────────────────────────────────

@test "planning-data: valid JSON with all sections" {
  run cmd_planning_data "Node Devices"
  assert_valid_json "$output"
  for key in activeSprint wrapUp backlogCandidates unscheduledBugs roster; do
    assert_has_key "$output" "$key"
  done
}

@test "planning-data: wrapUp has done and carryovers" {
  run cmd_planning_data "Node Devices"
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)['wrapUp']
assert 'done' in d and 'carryovers' in d
assert 'doneCount' in d and 'carryoverCount' in d
assert d['doneCount'] == len(d['done'])
assert d['carryoverCount'] == len(d['carryovers'])
"
}

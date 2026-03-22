#!/usr/bin/env bats
# Tests for lib/api/*.sh — low-level API commands with mocked HTTP

setup() {
  source "${BATS_TEST_DIRNAME}/test-helper.sh"
  load_all_mocked
}

# ── Sprint commands ────────────────────────────────────────────────────────────

@test "cmd_sprints filters to Node/Kueue sprints only" {
  run cmd_sprints active
  local count
  count=$(echo "$output" | python3 -c "import json,sys; print(len(json.load(sys.stdin).get('values',[])))")
  # Fixture has 4 sprints, 1 is "Unrelated" — should get 3
  [[ "$count" == "3" ]]
}

@test "cmd_sprints excludes non-Node sprints" {
  run cmd_sprints active
  [[ "$output" != *"Unrelated"* ]]
}

@test "cmd_sprint_issues returns issues array" {
  run cmd_sprint_issues 6171
  local total
  total=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin).get('total',0))")
  [[ "$total" == "3" ]]
}

@test "cmd_sprint_issues returns correct keys" {
  run cmd_sprint_issues 6171
  [[ "$output" == *"OCPNODE-1001"* ]]
  [[ "$output" == *"OCPNODE-1002"* ]]
  [[ "$output" == *"OCPNODE-1003"* ]]
}

# ── Issue commands ─────────────────────────────────────────────────────────────

@test "cmd_get returns full issue" {
  run cmd_get OCPNODE-1001
  [[ "$output" == *"Implement feature A"* ]]
  [[ "$output" == *"OCPNODE-900"* ]]  # epic link
}

@test "cmd_search returns search results" {
  run cmd_search "project = OCPBUGS"
  [[ "$output" == *"OCPBUGS-99001"* ]]
  [[ "$output" == *"OCPBUGS-99002"* ]]
}

# ── Comment commands ───────────────────────────────────────────────────────────

@test "cmd_comments returns comments list" {
  run cmd_comments OCPNODE-1001
  local total
  total=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin).get('total',0))")
  [[ "$total" == "3" ]]
}

@test "cmd_comments includes author names" {
  run cmd_comments OCPNODE-1001
  [[ "$output" == *"Alice Smith"* ]]
  [[ "$output" == *"Bob Jones"* ]]
}

# ── Transition commands ────────────────────────────────────────────────────────

@test "cmd_transitions returns available transitions" {
  run cmd_transitions OCPNODE-1001
  [[ "$output" == *"In Progress"* ]]
  [[ "$output" == *"Code Review"* ]]
  [[ "$output" == *"Closed"* ]]
}

@test "cmd_transitions includes transition IDs" {
  run cmd_transitions OCPNODE-1001
  local count
  count=$(echo "$output" | python3 -c "import json,sys; print(len(json.load(sys.stdin).get('transitions',[])))")
  [[ "$count" == "4" ]]
}

# ── Field parameter tests ────────────────────────────────────────────────────

@test "cmd_search accepts custom fields_json parameter" {
  local custom_fields='["key","summary","status"]'
  run cmd_search "project = OCPBUGS" 50 "$custom_fields"
  [[ "$output" == *"OCPBUGS-99001"* ]]
}

@test "cmd_get accepts fields parameter" {
  run cmd_get OCPNODE-1001 "summary,status"
  [[ "$output" == *"OCPNODE-1001"* ]]
}

@test "cmd_sprint_issues accepts custom fields parameter" {
  run cmd_sprint_issues 6171 100 "summary,status,assignee"
  [[ "$output" == *"OCPNODE-1001"* ]]
  [[ "$output" == *"OCPNODE-1002"* ]]
}

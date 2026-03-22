#!/usr/bin/env bats
# Tests for lib/core.sh — constants, JQL encoding, logging

setup() {
  source "${BATS_TEST_DIRNAME}/test-helper.sh"
  load_core_mocked
}

@test "JIRA_BASE is set correctly" {
  [[ "$JIRA_BASE" == "https://redhat.atlassian.net" ]]
}

@test "BOARD_ID defaults to 7845" {
  [[ "$BOARD_ID" == "7845" ]]
}

@test "BOARD_ID can be overridden via JIRA_BOARD_ID" {
  unset _CORE_LOADED
  JIRA_BOARD_ID=1234 source "${PROJECT_ROOT}/bin/lib/core.sh"
  [[ "$BOARD_ID" == "1234" ]]
}

@test "custom field constants are defined" {
  [[ "$CF_SPRINT" == "customfield_10020" ]]
  [[ "$CF_STORY_POINTS" == "customfield_10028" ]]
  [[ "$CF_EPIC_LINK" == "customfield_10014" ]]
  [[ "$CF_BLOCKED" == "customfield_10517" ]]
  [[ "$CF_BLOCKED_REASON" == "customfield_10483" ]]
  [[ "$CF_RELEASE_BLOCKER" == "customfield_10847" ]]
  [[ "$CF_SFDC_COUNTER" == "customfield_10978" ]]
  [[ "$CF_SFDC_LINKS" == "customfield_10979" ]]
  [[ "$CF_SEVERITY" == "customfield_10840" ]]
}

@test "_jql_encode encodes spaces" {
  local encoded
  encoded=$(_jql_encode "project = OCPNODE")
  [[ "$encoded" == "project%20%3D%20OCPNODE" ]]
}

@test "_jql_encode encodes special characters" {
  local encoded
  encoded=$(_jql_encode 'status in ("To Do", "In Progress")')
  [[ "$encoded" == *"%28"* ]]  # encoded parenthesis
  [[ "$encoded" == *"%22"* ]]  # encoded quotes
}

@test "_jql_encode handles empty string" {
  local encoded
  encoded=$(_jql_encode "")
  [[ "$encoded" == "" ]]
}

@test "_log writes to stderr" {
  run bash -c 'source '"${PROJECT_ROOT}"'/bin/lib/core.sh; _log "INFO" "test message" 2>&1'
  [[ "$output" == *"INFO"* ]]
  [[ "$output" == *"test message"* ]]
}

@test "ISSUE_FIELDS contains all required custom fields" {
  [[ "$ISSUE_FIELDS" == *"customfield_10020"* ]]
  [[ "$ISSUE_FIELDS" == *"customfield_10028"* ]]
  [[ "$ISSUE_FIELDS" == *"customfield_10014"* ]]
  [[ "$ISSUE_FIELDS" == *"customfield_10517"* ]]
}

@test "SEARCH_FIELDS_JSON is valid JSON array" {
  echo "$SEARCH_FIELDS_JSON" | python3 -c "import json,sys; assert isinstance(json.load(sys.stdin), list)"
}

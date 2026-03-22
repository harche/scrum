#!/usr/bin/env bats
# Tests for health-check command — validates field metadata against Jira

setup() {
  source "${BATS_TEST_DIRNAME}/test-helper.sh"
  load_all_mocked
}

@test "health-check: returns valid JSON" {
  run cmd_health_check
  echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)"
}

@test "health-check: reports HEALTHY when all fields match" {
  run cmd_health_check
  [[ "$output" == *'"status": "HEALTHY"'* ]]
}

@test "health-check: checks all 10 custom fields" {
  run cmd_health_check
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['summary']['fieldsChecked'] == 10, f'Expected 10 fields checked, got {d[\"summary\"][\"fieldsChecked\"]}'
assert d['summary']['errors'] == 0
assert d['summary']['warnings'] == 0
"
}

@test "health-check: each field has id, expected, status" {
  run cmd_health_check
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for f in d['fields']:
    assert 'id' in f, f'Field missing id'
    assert 'expected' in f, f'Field {f[\"id\"]} missing expected'
    assert 'status' in f, f'Field {f[\"id\"]} missing status'
    assert f['status'] == 'OK', f'Field {f[\"id\"]} status is {f[\"status\"]}, expected OK'
"
}

@test "health-check: reports UNHEALTHY when fields are missing" {
  # Override _curl to return empty field list
  _curl() {
    local url=""
    for arg in "$@"; do [[ "$arg" == http* ]] && url="$arg"; done
    [[ "$url" == */field ]] && { echo '[]'; return; }
    _mock_curl "$@"
  }
  run cmd_health_check
  [[ "$output" == *'"status": "UNHEALTHY"'* ]]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['summary']['errors'] >= 10, f'Expected at least 10 errors (custom fields), got {d[\"summary\"][\"errors\"]}'
"
}

@test "health-check: reports DEGRADED when field is renamed" {
  _curl() {
    local url=""
    for arg in "$@"; do [[ "$arg" == http* ]] && url="$arg"; done
    if [[ "$url" == */field ]]; then
      python3 -c "
import json
with open('$FIXTURES/field-metadata.json') as f:
    fields = json.load(f)
for f in fields:
    if f['id'] == 'customfield_10847':
        f['name'] = 'Release Blocker v2'
print(json.dumps(fields))
"
      return
    fi
    _mock_curl "$@"
  }
  run cmd_health_check
  [[ "$output" == *'"status": "DEGRADED"'* ]]
  [[ "$output" == *"name changed"* ]]
}

@test "health-check: reports DEGRADED when field type changes" {
  _curl() {
    local url=""
    for arg in "$@"; do [[ "$arg" == http* ]] && url="$arg"; done
    if [[ "$url" == */field ]]; then
      python3 -c "
import json
with open('$FIXTURES/field-metadata.json') as f:
    fields = json.load(f)
for f in fields:
    if f['id'] == 'customfield_10028':
        f['schema']['type'] = 'string'
print(json.dumps(fields))
"
      return
    fi
    _mock_curl "$@"
  }
  run cmd_health_check
  [[ "$output" == *'"status": "DEGRADED"'* ]]
  [[ "$output" == *"type changed"* ]]
}

@test "health-check: validates standard fields exist" {
  run cmd_health_check
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['missingStandardFields'] == [], f'Unexpected missing standard fields: {d[\"missingStandardFields\"]}'
"
}

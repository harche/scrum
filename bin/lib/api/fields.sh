#!/bin/bash
# API commands: set fields, set story points, move to sprint
# Sourced by jira.sh — requires core.sh

[[ -n "${_API_FIELDS_LOADED:-}" ]] && return 0
_API_FIELDS_LOADED=1

cmd_set_points() {
  local key="$1"
  local points="$2"
  _curl -X PUT "${JIRA_BASE}/rest/api/3/issue/${key}" \
    -d "{\"fields\": {\"${CF_STORY_POINTS}\": ${points}}}"
}

cmd_set_field() {
  local key="$1"
  local field="$2"
  local value="$3"
  local payload
  payload=$(python3 -c "
import json, sys
key, field, value = sys.argv[1], sys.argv[2], sys.argv[3]
# Try parsing as JSON first (for arrays, objects, numbers, booleans)
try:
    parsed = json.loads(value)
except (json.JSONDecodeError, ValueError):
    parsed = value  # plain string
print(json.dumps({'fields': {field: parsed}}))
" "$key" "$field" "$value")
  local result
  result=$(_curl -X PUT "${JIRA_BASE}/rest/api/3/issue/${key}" -d "$payload" -w "\nHTTP_%{http_code}")
  local code
  code=$(echo "$result" | grep "HTTP_" | sed 's/HTTP_//')
  if [[ "$code" == "204" ]]; then
    echo "{\"key\":\"${key}\",\"field\":\"${field}\",\"status\":\"ok\"}"
  else
    local body
    body=$(echo "$result" | grep -v "HTTP_")
    echo "{\"key\":\"${key}\",\"field\":\"${field}\",\"status\":\"error\",\"code\":\"${code}\",\"response\":${body:-\"{}\"}}" >&2
    return 1
  fi
}

cmd_link() {
  local key="$1"
  local url="$2"
  local title="${3:-$url}"
  local payload
  payload=$(python3 -c "
import json, sys
url, title = sys.argv[1], sys.argv[2]
# Auto-detect icon for GitHub URLs
icon = {}
if 'github.com' in url:
    icon = {'url16x16': 'https://github.com/favicon.ico', 'title': 'GitHub'}
print(json.dumps({
    'object': {
        'url': url,
        'title': title,
        'icon': icon
    }
}))
" "$url" "$title")
  local result
  result=$(_curl -X POST "${JIRA_BASE}/rest/api/3/issue/${key}/remotelink" -d "$payload" -w "\nHTTP_%{http_code}")
  local code
  code=$(echo "$result" | grep "HTTP_" | sed 's/HTTP_//')
  if [[ "$code" == "200" || "$code" == "201" ]]; then
    echo "{\"key\":\"${key}\",\"url\":\"${url}\",\"status\":\"ok\"}"
  else
    local body
    body=$(echo "$result" | grep -v "HTTP_")
    echo "{\"key\":\"${key}\",\"url\":\"${url}\",\"status\":\"error\",\"code\":\"${code}\",\"response\":${body:-\"{}\"}}" >&2
    return 1
  fi
}

cmd_move_to_sprint() {
  local sprint_id="$1"
  shift
  local issues=("$@")
  local json_issues
  json_issues=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1:]))" "${issues[@]}")
  _curl -X POST "${JIRA_BASE}/rest/agile/1.0/sprint/${sprint_id}/issue" -d "{\"issues\": ${json_issues}}"
}

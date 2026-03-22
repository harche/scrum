#!/bin/bash
# API commands: list and add comments
# Sourced by jira.sh — requires core.sh

[[ -n "${_API_COMMENT_LOADED:-}" ]] && return 0
_API_COMMENT_LOADED=1

cmd_comments() {
  local key="$1"
  _curl "${JIRA_BASE}/rest/api/3/issue/${key}/comment"
}

cmd_comment() {
  local body="$1"
  shift
  local keys=("$@")
  local payload
  payload=$(python3 -c "
import json, sys
body = sys.argv[1]
print(json.dumps({
  'body': {
    'version': 1,
    'type': 'doc',
    'content': [{'type': 'paragraph', 'content': [{'type': 'text', 'text': body}]}]
  }
}))
" "$body")
  for key in "${keys[@]}"; do
    local result
    result=$(_curl -X POST "${JIRA_BASE}/rest/api/3/issue/${key}/comment" -d "$payload" -w "\nHTTP_%{http_code}" 2>&1)
    local code
    code=$(echo "$result" | grep "HTTP_" | sed 's/HTTP_//')
    if [[ "$code" == "201" ]]; then
      echo "{\"key\":\"${key}\",\"status\":\"ok\"}"
    else
      echo "{\"key\":\"${key}\",\"status\":\"error\",\"code\":\"${code}\"}" >&2
    fi
  done
}

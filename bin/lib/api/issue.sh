#!/bin/bash
# API commands: issue search and get
# Sourced by jira.sh — requires core.sh

[[ -n "${_API_ISSUE_LOADED:-}" ]] && return 0
_API_ISSUE_LOADED=1

cmd_search() {
  local jql="$1"
  local limit="${2:-50}"
  local payload
  payload=$(python3 -c "
import json, sys
print(json.dumps({
  'jql': sys.argv[1],
  'maxResults': int(sys.argv[2]),
  'fields': json.loads(sys.argv[3])
}))
" "$jql" "$limit" "$SEARCH_FIELDS_JSON")
  _curl -X POST "${JIRA_BASE}/rest/api/3/search/jql" -d "$payload"
}

cmd_get() {
  local key="$1"
  _curl "${JIRA_BASE}/rest/api/3/issue/${key}"
}

#!/bin/bash
# API commands: set story points, move to sprint
# Sourced by jira.sh — requires core.sh

[[ -n "${_API_FIELDS_LOADED:-}" ]] && return 0
_API_FIELDS_LOADED=1

cmd_set_points() {
  local key="$1"
  local points="$2"
  _curl -X PUT "${JIRA_BASE}/rest/api/3/issue/${key}" \
    -d "{\"fields\": {\"${CF_STORY_POINTS}\": ${points}}}"
}

cmd_move_to_sprint() {
  local sprint_id="$1"
  shift
  local issues=("$@")
  local json_issues
  json_issues=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1:]))" "${issues[@]}")
  _curl -X POST "${JIRA_BASE}/rest/agile/1.0/sprint/${sprint_id}/issue" -d "{\"issues\": ${json_issues}}"
}

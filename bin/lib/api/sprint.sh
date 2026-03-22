#!/bin/bash
# API commands: sprint discovery and sprint issues
# Sourced by jira.sh — requires core.sh

[[ -n "${_API_SPRINT_LOADED:-}" ]] && return 0
_API_SPRINT_LOADED=1

cmd_sprints() {
  local state="${1:-active}"
  local result
  result=$(_curl "${JIRA_BASE}/rest/agile/1.0/board/${BOARD_ID}/sprint?state=${state}&maxResults=50")
  # Filter to Node-related sprints only
  python3 - "$result" <<'PYEOF'
import sys, json
data = json.loads(sys.argv[1])
sprints = []
for s in data.get('values', []):
    name = s.get('name', '')
    if 'Node' in name or 'Kueue' in name:
        sprints.append(s)
sprints.sort(key=lambda x: x.get('startDate', ''), reverse=True)
print(json.dumps({'values': sprints}))
PYEOF
}

cmd_sprint_issues() {
  local sprint_id="$1"
  local limit="${2:-100}"
  _curl "${JIRA_BASE}/rest/agile/1.0/sprint/${sprint_id}/issue?maxResults=${limit}&fields=${ISSUE_FIELDS}"
}

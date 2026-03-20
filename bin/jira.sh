#!/bin/bash
# Jira API helper for Node Devices scrum workflows
# Auth: Basic auth using macOS Keychain
# No PII hardcoded — reads credentials from Keychain
# Uses Agile REST API (sprints, sprint-issues) with REST API v3 fallback (search, get, comments, transitions)

set -euo pipefail

JIRA_BASE="https://redhat.atlassian.net"
BOARD_ID="${JIRA_BOARD_ID:-7845}"

# Auth
JIRA_API_TOKEN=$(security find-generic-password -s "JIRA_API_TOKEN" -w 2>/dev/null) || {
  echo '{"error": "JIRA_API_TOKEN not found in Keychain"}' >&2; exit 1
}
JIRA_USER=$(security find-generic-password -s "JIRA_API_TOKEN" -a "" -g 2>&1 | grep "acct" | sed 's/.*="//;s/"//' 2>/dev/null) || true
if [[ -z "$JIRA_USER" ]]; then
  JIRA_USER="${JIRA_EMAIL:-$(git config user.email 2>/dev/null || echo "")}"
fi
if [[ -z "$JIRA_USER" ]]; then
  echo '{"error": "Cannot determine Jira email. Set JIRA_EMAIL env var."}' >&2; exit 1
fi

AUTH="-u ${JIRA_USER}:${JIRA_API_TOKEN}"

_curl() {
  curl -s $AUTH -H "Content-Type: application/json" "$@"
}

_jql_encode() {
  python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$1"
}

cmd_search() {
  local jql="$1"
  local limit="${2:-50}"
  local payload
  payload=$(python3 -c "
import json, sys
print(json.dumps({
  'jql': sys.argv[1],
  'maxResults': int(sys.argv[2]),
  'fields': ['key','summary','status','assignee','priority','issuetype','fixVersions',
             'customfield_10020','customfield_10028','customfield_10014','customfield_10517','customfield_10483','customfield_10847']
}))
" "$jql" "$limit")
  _curl -X POST "${JIRA_BASE}/rest/api/3/search/jql" -d "$payload"
}

cmd_get() {
  local key="$1"
  _curl "${JIRA_BASE}/rest/api/3/issue/${key}"
}

cmd_sprints() {
  local state="${1:-active}"
  # Use Agile API directly — returns all sprints for the board without needing issue searches
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
  local fields="key,summary,status,assignee,priority,issuetype,fixVersions,customfield_10020,customfield_10028,customfield_10014,customfield_10517,customfield_10483,customfield_10847"
  _curl "${JIRA_BASE}/rest/agile/1.0/sprint/${sprint_id}/issue?maxResults=${limit}&fields=${fields}"
}

cmd_comments() {
  local key="$1"
  _curl "${JIRA_BASE}/rest/api/3/issue/${key}/comment"
}

cmd_transitions() {
  local key="$1"
  _curl "${JIRA_BASE}/rest/api/3/issue/${key}/transitions"
}

cmd_comment() {
  local key="$1"
  local body="$2"
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
  _curl -X POST "${JIRA_BASE}/rest/api/3/issue/${key}/comment" -d "$payload"
}

cmd_set_points() {
  local key="$1"
  local points="$2"
  _curl -X PUT "${JIRA_BASE}/rest/api/3/issue/${key}" \
    -d "{\"fields\": {\"customfield_10028\": ${points}}}"
}

cmd_move_to_sprint() {
  local sprint_id="$1"
  shift
  local issues=("$@")
  local json_issues
  json_issues=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1:]))" "${issues[@]}")
  _curl -X POST "${JIRA_BASE}/rest/agile/1.0/sprint/${sprint_id}/issue" -d "{\"issues\": ${json_issues}}"
}

cmd_help() {
  cat <<'EOF'
Usage: jira.sh <command> [args]

Commands:
  search <JQL> [limit]        Search issues (default limit: 50)
  get <ISSUE-KEY>             Get full issue details
  sprints [state]             List sprints (active|future|closed)
  sprint-issues <sprintId> [limit]  Get issues in a sprint (default limit: 100)
  move-to-sprint <sprintId> <KEY...> Move issue(s) to a sprint
  set-points <ISSUE-KEY> <points>   Set story points on an issue
  comments <ISSUE-KEY>        List comments on an issue
  comment <ISSUE-KEY> <body>   Add a comment to an issue
  transitions <ISSUE-KEY>     Get available transitions

Notes:
  - Uses Agile API for sprints/sprint-issues, REST API v3 for everything else
  - API v3 returns descriptions and comments in Atlassian Document Format (ADF).
    Use the adf_to_text() Python helper to convert ADF to plain text:
      python3 -c "
      def adf_to_text(node):
          if isinstance(node, str): return node
          if not isinstance(node, dict): return ''
          text = ''
          if node.get('type') == 'text':
              text = node.get('text', '')
          for child in node.get('content', []):
              text += adf_to_text(child)
          if node.get('type') in ('paragraph','heading','listItem','blockquote'):
              text += '\n'
          if node.get('type') == 'hardBreak':
              text += '\n'
          return text
      "

Environment:
  JIRA_EMAIL       Override Jira email (default: git config user.email)
  JIRA_BOARD_ID    Override board ID (default: 7845)
EOF
}

case "${1:-help}" in
  search)         cmd_search "${2:?JQL required}" "${3:-50}" ;;
  get)            cmd_get "${2:?ISSUE-KEY required}" ;;
  sprints)        cmd_sprints "${2:-active}" ;;
  sprint-issues)  cmd_sprint_issues "${2:?Sprint ID required}" "${3:-100}" ;;
  comments)       cmd_comments "${2:?ISSUE-KEY required}" ;;
  comment)        cmd_comment "${2:?ISSUE-KEY required}" "${3:?Comment body required}" ;;
  move-to-sprint) cmd_move_to_sprint "${2:?Sprint ID required}" "${@:3}" ;;
  set-points)     cmd_set_points "${2:?ISSUE-KEY required}" "${3:?Story points required}" ;;
  transitions)    cmd_transitions "${2:?ISSUE-KEY required}" ;;
  help|--help|-h) cmd_help ;;
  *)              echo "Unknown command: $1" >&2; cmd_help >&2; exit 1 ;;
esac

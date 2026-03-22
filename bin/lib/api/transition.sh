#!/bin/bash
# API commands: transitions, transition, close
# Sourced by jira.sh — requires core.sh

[[ -n "${_API_TRANSITION_LOADED:-}" ]] && return 0
_API_TRANSITION_LOADED=1

cmd_transitions() {
  local key="$1"
  _curl "${JIRA_BASE}/rest/api/3/issue/${key}/transitions"
}

cmd_transition() {
  local transition_id="$1"
  shift
  local keys=("$@")
  for key in "${keys[@]}"; do
    local result
    result=$(_curl -X POST "${JIRA_BASE}/rest/api/3/issue/${key}/transitions" \
      -d "{\"transition\":{\"id\":\"${transition_id}\"}}" -w "\nHTTP_%{http_code}" 2>&1)
    local code
    code=$(echo "$result" | grep "HTTP_" | sed 's/HTTP_//')
    if [[ "$code" == "204" ]]; then
      echo "{\"key\":\"${key}\",\"status\":\"ok\"}"
    else
      echo "{\"key\":\"${key}\",\"status\":\"error\",\"code\":\"${code}\"}" >&2
    fi
  done
}

cmd_close() {
  local comment=""
  local keys=()
  # First arg is optional comment (if it doesn't look like an issue key)
  if [[ $# -ge 1 && ! "$1" =~ ^[A-Z]+-[0-9]+$ ]]; then
    comment="$1"
    shift
  fi
  keys=("$@")
  if [[ ${#keys[@]} -eq 0 ]]; then
    echo '{"error":"No issue keys provided"}' >&2
    return 1
  fi
  for key in "${keys[@]}"; do
    if [[ -n "$comment" ]]; then
      cmd_comment "$comment" "$key" > /dev/null
    fi
    cmd_transition 51 "$key"
  done
}

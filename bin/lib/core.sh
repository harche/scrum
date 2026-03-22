#!/bin/bash
# Core library: auth, HTTP, constants, logging
# Sourced by all other modules — never executed directly

[[ -n "${_CORE_LOADED:-}" ]] && return 0
_CORE_LOADED=1

# ── Constants ──────────────────────────────────────────────────────────────────

JIRA_BASE="https://redhat.atlassian.net"
BOARD_ID="${JIRA_BOARD_ID:-7845}"

# Custom field IDs
CF_SPRINT="customfield_10020"
CF_STORY_POINTS="customfield_10028"
CF_EPIC_LINK="customfield_10014"
CF_TARGET_VERSION="customfield_10855"
CF_RELEASE_BLOCKER="customfield_10847"
CF_SFDC_COUNTER="customfield_10978"
CF_SFDC_LINKS="customfield_10979"
CF_SEVERITY="customfield_10840"
CF_BLOCKED="customfield_10517"
CF_BLOCKED_REASON="customfield_10483"

# Standard fields requested by search/sprint-issues
ISSUE_FIELDS="key,summary,status,assignee,priority,issuetype,fixVersions,components,${CF_SPRINT},${CF_STORY_POINTS},${CF_EPIC_LINK},${CF_BLOCKED},${CF_BLOCKED_REASON},${CF_RELEASE_BLOCKER}"
SEARCH_FIELDS_JSON="[\"key\",\"summary\",\"status\",\"assignee\",\"priority\",\"issuetype\",\"fixVersions\",\"components\",\"${CF_SPRINT}\",\"${CF_STORY_POINTS}\",\"${CF_EPIC_LINK}\",\"${CF_BLOCKED}\",\"${CF_BLOCKED_REASON}\",\"${CF_RELEASE_BLOCKER}\"]"

# ── Logging ────────────────────────────────────────────────────────────────────

_log() {
  local level="$1"; shift
  echo "[$(date -u +%H:%M:%S)] ${level}: $*" >&2
}

# ── Python check ───────────────────────────────────────────────────────────────

_check_python() {
  command -v python3 >/dev/null 2>&1 || {
    echo '{"error":"python3 is required but not found"}' >&2
    exit 1
  }
}

# ── Auth ───────────────────────────────────────────────────────────────────────

_init_auth() {
  [[ -n "${_AUTH_INITIALIZED:-}" ]] && return 0
  _AUTH_INITIALIZED=1

  JIRA_API_TOKEN=$(security find-generic-password -s "JIRA_API_TOKEN" -w 2>/dev/null) || {
    echo '{"error": "JIRA_API_TOKEN not found in Keychain"}' >&2; exit 1
  }

  JIRA_USER=$(security find-generic-password -s "JIRA_API_TOKEN" -g 2>&1 | grep "acct" | sed 's/.*="//;s/"//' 2>/dev/null) || true
  if [[ -n "$JIRA_USER" && ! "$JIRA_USER" =~ "@" ]]; then
    JIRA_USER="${JIRA_USER}@redhat.com"
  fi
  if [[ -z "$JIRA_USER" ]]; then
    JIRA_USER="${JIRA_EMAIL:-$(git config user.email 2>/dev/null || echo "")}"
  fi
  if [[ -z "$JIRA_USER" ]]; then
    echo '{"error": "Cannot determine Jira email. Set JIRA_EMAIL env var."}' >&2; exit 1
  fi

  AUTH="-u ${JIRA_USER}:${JIRA_API_TOKEN}"
}

# ── HTTP ───────────────────────────────────────────────────────────────────────

_curl() {
  _init_auth
  curl -s $AUTH -H "Content-Type: application/json" "$@"
}

# ── Utilities ──────────────────────────────────────────────────────────────────

_jql_encode() {
  python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$1"
}

# ADF-to-text conversion via Python helper
_adf_to_text() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  python3 "${script_dir}/util/adf.py" "$@"
}

#!/bin/bash
# Shared test helper — sets up fixtures and mocks for all test files

export FIXTURES="${BATS_TEST_DIRNAME}/fixtures"
export PROJECT_ROOT="${BATS_TEST_DIRNAME}/.."

# Mock _curl to return fixture data based on URL patterns
_mock_curl() {
  local method=""
  local url=""
  local data=""

  # Parse curl-like args to find URL and method
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -X)       method="$2"; shift 2 ;;
      -d)       data="$2"; shift 2 ;;
      -w|-H|-u|-s|--max-time) shift 2 ;;  # skip flag+value pairs
      -o)       shift 2 ;;
      http*)    url="$1"; shift ;;
      *)        shift ;;
    esac
  done

  # Route to fixture based on URL pattern
  case "$url" in
    */board/*/sprint*)         cat "$FIXTURES/sprint-list.json" ;;
    */sprint/*/issue*)         cat "$FIXTURES/sprint-issues.json" ;;
    */search/jql)              cat "$FIXTURES/search-results.json" ;;
    */issue/*/comment)
      if [[ "$method" == "POST" ]]; then
        echo '{"id":"200001"}'; printf '\nHTTP_201'
      else
        cat "$FIXTURES/comments.json"
      fi
      ;;
    */issue/*/transitions)
      if [[ "$method" == "POST" ]]; then
        printf '\nHTTP_204'
      else
        cat "$FIXTURES/transitions.json"
      fi
      ;;
    */issue/*)
      if [[ "$method" == "PUT" ]]; then
        echo '{}'; printf '\nHTTP_204'
      else
        cat "$FIXTURES/issue-get.json"
      fi
      ;;
    */sprint/*/issue)
      if [[ "$method" == "POST" ]]; then
        echo '{}'; printf '\nHTTP_204'
      fi
      ;;
    */field)
      cat "$FIXTURES/field-metadata.json" ;;
    *)
      echo "{\"error\":\"Mock: unrecognized URL: ${url}\"}" >&2
      return 1
      ;;
  esac
}

# Source core with mocked _curl
load_core_mocked() {
  # Source core first (sets up constants, auth functions)
  source "${PROJECT_ROOT}/bin/lib/core.sh"
  # Override _curl with mock and mark auth as done
  _AUTH_INITIALIZED=1
  AUTH="-u test@example.com:fake-token"
  _curl() { _mock_curl "$@"; }
}

# Source all modules with mocked _curl
load_all_mocked() {
  load_core_mocked
  source "${PROJECT_ROOT}/bin/lib/api/issue.sh"
  source "${PROJECT_ROOT}/bin/lib/api/sprint.sh"
  source "${PROJECT_ROOT}/bin/lib/api/comment.sh"
  source "${PROJECT_ROOT}/bin/lib/api/transition.sh"
  source "${PROJECT_ROOT}/bin/lib/api/fields.sh"
  source "${PROJECT_ROOT}/bin/lib/api/health.sh"
  source "${PROJECT_ROOT}/bin/lib/util/cache.sh"
  source "${PROJECT_ROOT}/bin/lib/team.sh"
}

#!/bin/bash
# File-based caching for sprint discovery and other slow queries
# Cache lives in $TMPDIR, scoped to process tree, auto-cleaned on exit

[[ -n "${_CACHE_LOADED:-}" ]] && return 0
_CACHE_LOADED=1

_CACHE_TTL="${JIRA_CACHE_TTL:-300}"  # 5 minutes default
_CACHE_DIR=""

_cache_init() {
  if [[ -z "$_CACHE_DIR" ]]; then
    _CACHE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/jira-cache-$$.XXXXXX")
    # Only set trap if not already set by parallel.sh
    if [[ -z "${_PARALLEL_DIR:-}" ]]; then
      trap '_cache_cleanup' EXIT
    fi
  fi
}

_cache_cleanup() {
  if [[ -n "$_CACHE_DIR" && -d "$_CACHE_DIR" ]]; then
    rm -rf "$_CACHE_DIR"
  fi
}

cache_get() {
  _cache_init
  local key="$1"
  local file="${_CACHE_DIR}/${key}"
  if [[ -f "$file" ]]; then
    local age
    age=$(( $(date +%s) - $(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo 0) ))
    if (( age < _CACHE_TTL )); then
      cat "$file"
      return 0
    fi
    rm -f "$file"
  fi
  return 1
}

cache_set() {
  _cache_init
  local key="$1"
  local value="$2"
  echo "$value" > "${_CACHE_DIR}/${key}"
}

# Cache-through wrapper for sprint discovery
cached_sprints() {
  local state="${1:-active}"
  local cache_key="sprints_${state}"
  local cached
  if cached=$(cache_get "$cache_key" 2>/dev/null); then
    echo "$cached"
    return 0
  fi
  local result
  result=$(cmd_sprints "$state")
  cache_set "$cache_key" "$result"
  echo "$result"
}

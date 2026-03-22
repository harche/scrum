#!/bin/bash
# Retry and error handling for HTTP requests
# Sourced by core.sh — provides _curl_with_retry wrapping _curl

[[ -n "${_RETRY_LOADED:-}" ]] && return 0
_RETRY_LOADED=1

_RETRY_MAX="${JIRA_RETRY_MAX:-3}"
_RETRY_TIMEOUT="${JIRA_TIMEOUT:-30}"

_curl_with_retry() {
  local attempt=0
  local delay=1
  local tmpfile
  tmpfile=$(mktemp)
  trap "rm -f '$tmpfile'" RETURN

  while (( attempt < _RETRY_MAX )); do
    attempt=$((attempt + 1))
    local http_code

    # Execute curl, capture body to tmpfile and HTTP code to variable
    http_code=$(curl -s $AUTH -H "Content-Type: application/json" \
      --max-time "$_RETRY_TIMEOUT" \
      -w "%{http_code}" \
      -o "$tmpfile" \
      "$@" 2>/dev/null) || {
        # curl itself failed (timeout, DNS, connection error)
        if (( attempt < _RETRY_MAX )); then
          _log "WARN" "curl failed (attempt ${attempt}/${_RETRY_MAX}), retrying in ${delay}s..."
          sleep "$delay"
          delay=$((delay * 2))
          continue
        fi
        echo '{"error":"Request failed after retries","cause":"connection"}' >&2
        return 1
      }

    case "$http_code" in
      2[0-9][0-9])
        # Success — output the body
        cat "$tmpfile"
        return 0
        ;;
      429)
        # Rate limited — respect Retry-After if present
        local retry_after
        retry_after=$(grep -i "^retry-after:" "$tmpfile" 2>/dev/null | awk '{print $2}' || echo "$delay")
        retry_after=${retry_after:-$delay}
        if (( attempt < _RETRY_MAX )); then
          _log "WARN" "Rate limited (429), retrying in ${retry_after}s (attempt ${attempt}/${_RETRY_MAX})..."
          sleep "$retry_after"
          delay=$((delay * 2))
          continue
        fi
        _log "ERROR" "Rate limited after ${_RETRY_MAX} retries"
        echo "{\"error\":\"Rate limited\",\"httpCode\":429}" >&2
        return 1
        ;;
      5[0-9][0-9])
        # Server error — retry with backoff
        if (( attempt < _RETRY_MAX )); then
          _log "WARN" "Server error (${http_code}), retrying in ${delay}s (attempt ${attempt}/${_RETRY_MAX})..."
          sleep "$delay"
          delay=$((delay * 2))
          continue
        fi
        _log "ERROR" "Server error ${http_code} after ${_RETRY_MAX} retries"
        echo "{\"error\":\"Server error\",\"httpCode\":${http_code}}" >&2
        return 1
        ;;
      4[0-9][0-9])
        # Client error — do not retry (400, 401, 403, 404, etc.)
        _log "ERROR" "Client error: HTTP ${http_code}"
        cat "$tmpfile" >&2
        return 1
        ;;
      *)
        _log "ERROR" "Unexpected HTTP status: ${http_code}"
        cat "$tmpfile" >&2
        return 1
        ;;
    esac
  done
}

# Graceful fallback: returns partial result with error marker instead of failing
_graceful_fallback() {
  local section="$1"
  shift
  local result
  if result=$("$@" 2>/dev/null); then
    echo "$result"
  else
    echo "{\"_section\":\"${section}\",\"error\":\"Failed to fetch ${section}\"}"
  fi
}

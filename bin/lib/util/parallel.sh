#!/bin/bash
# Parallel job management for composite commands
# Runs multiple API calls concurrently using background jobs + temp files

[[ -n "${_PARALLEL_LOADED:-}" ]] && return 0
_PARALLEL_LOADED=1

_PARALLEL_DIR=""
_PARALLEL_PID_LIST=""  # space-separated "name:pid" pairs

parallel_init() {
  _PARALLEL_DIR=$(mktemp -d "${TMPDIR:-/tmp}/jira-parallel-$$.XXXXXX")
  _PARALLEL_PID_LIST=""
  trap 'parallel_cleanup' EXIT
}

parallel_run() {
  local name="$1"
  shift
  ( "$@" > "${_PARALLEL_DIR}/${name}.json" 2>"${_PARALLEL_DIR}/${name}.err" ) &
  _PARALLEL_PID_LIST="${_PARALLEL_PID_LIST} ${name}:$!"
}

parallel_wait_all() {
  local failed=0
  local entry pid name
  for entry in $_PARALLEL_PID_LIST; do
    name="${entry%%:*}"
    pid="${entry##*:}"
    if ! wait "$pid" 2>/dev/null; then
      failed=1
      _log "WARN" "Parallel job '${name}' failed (PID ${pid})"
    fi
  done
  _PARALLEL_PID_LIST=""
  return $failed
}

parallel_get() {
  local name="$1"
  local outfile="${_PARALLEL_DIR}/${name}.json"
  if [[ -f "$outfile" ]]; then
    cat "$outfile"
  else
    echo "{\"error\":\"No result for job '${name}'\"}"
  fi
}

parallel_get_err() {
  local name="$1"
  local errfile="${_PARALLEL_DIR}/${name}.err"
  if [[ -f "$errfile" && -s "$errfile" ]]; then
    cat "$errfile"
  fi
}

parallel_cleanup() {
  if [[ -n "${_PARALLEL_DIR:-}" && -d "${_PARALLEL_DIR:-}" ]]; then
    rm -rf "$_PARALLEL_DIR"
  fi
  _PARALLEL_DIR=""
  _PARALLEL_PID_LIST=""
}

# Run a batch of commands with limited concurrency
parallel_batch() {
  local concurrency="$1"
  local func="$2"
  shift 2
  local args=("$@")
  local running=0

  for arg in "${args[@]}"; do
    parallel_run "$arg" "$func" "$arg"
    running=$((running + 1))
    if (( running >= concurrency )); then
      wait -n 2>/dev/null || true
      running=$((running - 1))
    fi
  done
  parallel_wait_all
}

# Stream results as JSON Lines — emit each completed job as a {_section, data} line
# Usage: parallel_stream_wait <section_prefix>
# Polls every 200ms, emits results as jobs complete
parallel_stream_wait() {
  local prefix="${1:-data}"
  local emitted=""
  local all_done=false
  local start_ms=$(($(date +%s) * 1000))

  while [[ "$all_done" != "true" ]]; do
    all_done=true
    for entry in $_PARALLEL_PID_LIST; do
      local name="${entry%%:*}"
      local pid="${entry##*:}"

      # Skip already emitted
      [[ "$emitted" == *" ${name} "* ]] && continue

      # Check if done
      if ! kill -0 "$pid" 2>/dev/null; then
        # Job finished — emit result
        local outfile="${_PARALLEL_DIR}/${name}.json"
        if [[ -f "$outfile" && -s "$outfile" ]]; then
          local elapsed_ms=$(( $(date +%s) * 1000 - start_ms ))
          python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
print(json.dumps({'_section': sys.argv[2], '_job': sys.argv[3], '_elapsed_ms': int(sys.argv[4]), 'data': data}))
" "$outfile" "$prefix" "$name" "$elapsed_ms"
        fi
        emitted="${emitted} ${name} "
      else
        all_done=false
      fi
    done

    [[ "$all_done" != "true" ]] && sleep 0.2
  done

  # Emit completion marker
  local total_ms=$(( $(date +%s) * 1000 - start_ms ))
  echo "{\"_section\":\"complete\",\"elapsed_ms\":${total_ms}}"
  _PARALLEL_PID_LIST=""
}

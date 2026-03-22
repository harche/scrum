#!/usr/bin/env bats
# Tests for lib/util/parallel.sh — parallel job management

setup() {
  source "${BATS_TEST_DIRNAME}/test-helper.sh"
  load_core_mocked
  source "${PROJECT_ROOT}/bin/lib/util/parallel.sh"
  parallel_init
}

teardown() {
  parallel_cleanup 2>/dev/null || true
}

@test "parallel_init creates temp directory" {
  [[ -d "$_PARALLEL_DIR" ]]
}

@test "parallel_run creates output file" {
  parallel_run "test_job" echo '{"result":"ok"}'
  wait
  [[ -f "${_PARALLEL_DIR}/test_job.json" ]]
}

@test "parallel_get returns job output" {
  parallel_run "test_job" echo '{"result":"ok"}'
  parallel_wait_all
  run parallel_get "test_job"
  [[ "$output" == '{"result":"ok"}' ]]
}

@test "parallel_wait_all succeeds when all jobs succeed" {
  parallel_run "job1" echo '{"a":1}'
  parallel_run "job2" echo '{"b":2}'
  run parallel_wait_all
  [[ "$status" -eq 0 ]]
}

@test "parallel_wait_all fails when a job fails" {
  parallel_run "good_job" echo '{"ok":true}'
  parallel_run "bad_job" bash -c "exit 1"
  run parallel_wait_all
  [[ "$status" -ne 0 ]]
}

@test "multiple parallel jobs run concurrently" {
  # Start 3 jobs that each sleep briefly
  parallel_run "fast1" bash -c 'echo "done1"'
  parallel_run "fast2" bash -c 'echo "done2"'
  parallel_run "fast3" bash -c 'echo "done3"'
  parallel_wait_all

  [[ "$(parallel_get fast1)" == "done1" ]]
  [[ "$(parallel_get fast2)" == "done2" ]]
  [[ "$(parallel_get fast3)" == "done3" ]]
}

@test "parallel_get returns error for missing job" {
  run parallel_get "nonexistent"
  [[ "$output" == *"error"* ]]
}

@test "parallel_cleanup removes temp directory" {
  local dir="$_PARALLEL_DIR"
  parallel_cleanup
  [[ ! -d "$dir" ]]
}

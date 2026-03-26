#!/usr/bin/env bats
# Tests for lib/team.sh — team configuration and sprint resolution

setup() {
  source "${BATS_TEST_DIRNAME}/test-helper.sh"
  load_all_mocked
}

# ── team_config ────────────────────────────────────────────────────────────────

@test "team_config 'Node Devices' sets correct sprint filter" {
  team_config "Node Devices"
  [[ "$TEAM_SPRINT_FILTER" == "Node Devices" ]]
}

@test "team_config 'Node Devices' sets correct roster file" {
  team_config "Node Devices"
  [[ "$TEAM_ROSTER_FILE" == *"team-roster-dra.json" ]]
}

@test "team_config 'Node Devices' sets correct bug components" {
  team_config "Node Devices"
  [[ "$TEAM_BUG_COMPONENTS" == *"Device Manager"* ]]
  [[ "$TEAM_BUG_COMPONENTS" == *"Instaslice"* ]]
}

@test "team_config 'Node Core' sets correct sprint filter" {
  team_config "Node Core"
  [[ "$TEAM_SPRINT_FILTER" == "Node Core" ]]
}

@test "team_config 'Node Core' sets correct roster file" {
  team_config "Node Core"
  [[ "$TEAM_ROSTER_FILE" == *"team-roster-core.json" ]]
}

@test "team_config 'Node Core' includes all Node components" {
  team_config "Node Core"
  [[ "$TEAM_BUG_COMPONENTS" == *"CRI-O"* ]]
  [[ "$TEAM_BUG_COMPONENTS" == *"Kubelet"* ]]
  [[ "$TEAM_BUG_COMPONENTS" == *"CPU manager"* ]]
  [[ "$TEAM_BUG_COMPONENTS" == *"Kueue"* ]]
}

@test "team_config accepts 'dra' alias" {
  team_config "dra"
  [[ "$TEAM_NAME" == "Node Devices" ]]
}

@test "team_config accepts 'core' alias" {
  team_config "core"
  [[ "$TEAM_NAME" == "Node Core" ]]
}

@test "team_config rejects unknown team" {
  run team_config "Unknown Team"
  [[ "$status" -ne 0 ]]
}

# ── team_roster ────────────────────────────────────────────────────────────────

@test "team_roster returns DRA members" {
  run team_roster "Node Devices"
  local count
  count=$(echo "$output" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
  [[ "$count" == "10" ]]
}

@test "team_roster entries have name and github fields" {
  run team_roster "Node Devices"
  echo "$output" | python3 -c "
import json, sys
members = json.load(sys.stdin)
for m in members:
    assert 'name' in m and m['name'], f'Member missing name: {m}'
    assert 'github' in m and m['github'], f'Member missing github: {m}'
"
}

@test "team_roster returns Core members" {
  run team_roster "Node Core"
  local count
  count=$(echo "$output" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
  [[ "$count" == "17" ]]
}

# ── team_sprint ────────────────────────────────────────────────────────────────

@test "team_sprint finds Node Devices sprint" {
  run team_sprint "Node Devices" active
  [[ "$output" == *"OCP Node Devices Sprint 285"* ]]
  [[ "$output" == *"6171"* ]]
}

@test "team_sprint finds Node Core sprint" {
  run team_sprint "Node Core" active
  [[ "$output" == *"OCP Node Core Sprint 285"* ]]
  [[ "$output" == *"6170"* ]]
}

@test "team_sprint returns startDate and endDate" {
  run team_sprint "Node Devices" active
  [[ "$output" == *"startDate"* ]]
  [[ "$output" == *"endDate"* ]]
}

@test "team_sprint output is valid JSON" {
  run team_sprint "Node Devices" active
  echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)"
}

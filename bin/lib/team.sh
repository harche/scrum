#!/bin/bash
# Team configuration: resolves team name to sprint filter, roster, bug components
# Sourced by jira.sh — requires core.sh

[[ -n "${_TEAM_LOADED:-}" ]] && return 0
_TEAM_LOADED=1

# Resolve team name to config variables
# Usage: team_config "Node Devices" or team_config "Node Core"
team_config() {
  local team="$1"
  local root_dir
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

  # All Node-related components (used to distinguish "outside scope" vs "other Node team" bugs)
  ALL_NODE_COMPONENTS='"Node", "Node / CRI-O", "Node / Kubelet", "Node / CPU manager", "Node / Memory manager", "Node / Topology manager", "Node / Numa aware Scheduling", "Node / Device Manager", "Node / Pod resource API", "Node / Node Problem Detector", "Node / Kueue", "Node / Instaslice-operator"'

  case "$team" in
    "Node Devices"|"DRA"|"devices"|"dra")
      TEAM_NAME="Node Devices"
      TEAM_SPRINT_FILTER="Node Devices"
      TEAM_ROSTER_FILE="${root_dir}/config/team-roster-dra.json"
      TEAM_BUG_COMPONENTS='"Node / Device Manager", "Node / Instaslice-operator"'
      TEAM_BACKLOG_KEYWORDS="DRA DAS Instaslice device"
      ;;
    "Node Core"|"Core"|"core")
      TEAM_NAME="Node Core"
      TEAM_SPRINT_FILTER="Node Core"
      TEAM_ROSTER_FILE="${root_dir}/config/team-roster-core.json"
      TEAM_BUG_COMPONENTS='"Node", "Node / CRI-O", "Node / Kubelet", "Node / CPU manager", "Node / Memory manager", "Node / Topology manager", "Node / Numa aware Scheduling", "Node / Device Manager", "Node / Pod resource API", "Node / Node Problem Detector", "Node / Kueue", "Node / Instaslice-operator"'
      TEAM_BACKLOG_KEYWORDS=""
      ;;
    "all"|"All"|"All Node")
      TEAM_NAME="All Node"
      TEAM_SPRINT_FILTER=""
      TEAM_ROSTER_FILE=""
      TEAM_BUG_COMPONENTS="$ALL_NODE_COMPONENTS"
      TEAM_BACKLOG_KEYWORDS=""
      ;;
    *)
      echo "{\"error\":\"Unknown team: ${team}. Use 'Node Devices', 'Node Core', or 'all'.\"}" >&2
      return 1
      ;;
  esac
}

# Load team roster as JSON array: [{name, github}, ...]
team_roster() {
  local team="${1:-}"
  [[ -n "$team" ]] && team_config "$team"

  local root_dir
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

  # "all" team: merge both rosters (deduplicated)
  if [[ -z "$TEAM_ROSTER_FILE" ]]; then
    python3 -c "
import json, sys
members = {}
for f in sys.argv[1:]:
    with open(f) as fh:
        for k, v in json.load(fh).get('members', {}).items():
            members[k] = v
print(json.dumps([{'name': k, 'github': v} for k, v in members.items()]))
" "${root_dir}/config/team-roster-dra.json" "${root_dir}/config/team-roster-core.json"
    return 0
  fi

  if [[ ! -f "$TEAM_ROSTER_FILE" ]]; then
    echo "{\"error\":\"Roster file not found: ${TEAM_ROSTER_FILE}\"}" >&2
    return 1
  fi

  python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
members = [{'name': k, 'github': v} for k, v in data.get('members', {}).items()]
print(json.dumps(members))
" "$TEAM_ROSTER_FILE"
}

# Find the active (or specified state) sprint for a team
# Returns JSON: {id, name, startDate, endDate, goal}
team_sprint() {
  local team="$1"
  local state="${2:-active}"

  [[ -z "${TEAM_SPRINT_FILTER:-}" ]] && team_config "$team"

  local sprints
  if type -t cached_sprints >/dev/null 2>&1; then
    sprints=$(cached_sprints "$state")
  else
    sprints=$(cmd_sprints "$state")
  fi

  python3 -c "
import json, sys
data = json.loads(sys.argv[1])
team_filter = sys.argv[2]
for s in data.get('values', []):
    if team_filter in s.get('name', ''):
        print(json.dumps({
            'id': s['id'],
            'name': s['name'],
            'startDate': s.get('startDate', ''),
            'endDate': s.get('endDate', ''),
            'goal': s.get('goal', '')
        }))
        sys.exit(0)
print(json.dumps({'error': f'No {team_filter} sprint found with state={sys.argv[3]}'}))
sys.exit(1)
" "$sprints" "$TEAM_SPRINT_FILTER" "$state"
}

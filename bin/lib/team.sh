#!/bin/bash
# Team configuration: resolves team name to sprint filter, roster, bug components
# Sourced by jira.sh — requires core.sh

[[ -n "${_TEAM_LOADED:-}" ]] && return 0
_TEAM_LOADED=1

# Print a clear error when a roster file is missing, then exit
_roster_missing() {
  local file="$1"
  local example="${file%.json}.example.json"
  cat >&2 <<EOF

ERROR: Team roster file not found: ${file}

Roster files map Jira display names to GitHub handles for activity lookups.
They are not checked into the repo to avoid exposing personal information.

To set up your roster:

  1. Copy the example file:
     cp ${example} ${file}

  2. Edit it with your team members. The format is:
     {
       "description": "Brief description of this roster",
       "members": {
         "Jira Display Name": "github-handle",
         "Another Person": "their-github-handle"
       }
     }

  Jira display names must match exactly (check the assignee field in Jira).
  GitHub handles are used by /standup-github and /my-prs commands.

EOF
  exit 1
}

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
    local dra_file="${root_dir}/config/team-roster-dra.json"
    local core_file="${root_dir}/config/team-roster-core.json"
    [[ ! -f "$dra_file" ]] && _roster_missing "$dra_file"
    [[ ! -f "$core_file" ]] && _roster_missing "$core_file"
    python3 -c "
import json, sys
members = {}
for f in sys.argv[1:]:
    with open(f) as fh:
        for k, v in json.load(fh).get('members', {}).items():
            members[k] = v
print(json.dumps([{'name': k, 'github': v} for k, v in members.items()]))
" "$dra_file" "$core_file"
    return 0
  fi

  if [[ ! -f "$TEAM_ROSTER_FILE" ]]; then
    _roster_missing "$TEAM_ROSTER_FILE"
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
print(json.dumps({'error': f'No {team_filter} sprint found with state={sys.argv[3]}'}), file=sys.stderr)
sys.exit(1)
" "$sprints" "$TEAM_SPRINT_FILTER" "$state"
}

# Find the active sprint, falling back to the most recently closed sprint.
# Returns JSON: {id, name, startDate, endDate, goal, state}
# The "state" field indicates whether this is "active" or "closed" (fallback).
team_sprint_fallback() {
  local team="$1"

  [[ -z "${TEAM_SPRINT_FILTER:-}" ]] && team_config "$team"

  # Try active first
  local active_result
  active_result=$(team_sprint "$team" active 2>/dev/null) && {
    # Add state field so callers know this is a live active sprint
    echo "$active_result" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['state'] = 'active'
print(json.dumps(d))
"
    return 0
  }

  # Fall back to most recently closed sprint
  local closed_sprints
  if type -t cached_sprints >/dev/null 2>&1; then
    closed_sprints=$(cached_sprints "closed")
  else
    closed_sprints=$(cmd_sprints "closed")
  fi

  python3 -c "
import json, sys
data = json.loads(sys.argv[1])
team_filter = sys.argv[2]
# cmd_sprints already sorts by startDate descending, so first match is most recent
for s in data.get('values', []):
    if team_filter in s.get('name', ''):
        print(json.dumps({
            'id': s['id'],
            'name': s['name'],
            'startDate': s.get('startDate', ''),
            'endDate': s.get('endDate', ''),
            'goal': s.get('goal', ''),
            'state': 'closed',
        }))
        sys.exit(0)
print(json.dumps({'error': f'No {team_filter} sprint found (active or closed)'}), file=sys.stderr)
sys.exit(1)
" "$closed_sprints" "$TEAM_SPRINT_FILTER"
}

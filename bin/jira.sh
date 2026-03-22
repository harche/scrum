#!/bin/bash
# Jira CLI — thin dispatcher
# Sources modular libraries from lib/ and dispatches subcommands
# All existing commands are backward-compatible; composite commands are additive.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Load modules ───────────────────────────────────────────────────────────────

source "${SCRIPT_DIR}/lib/core.sh"
source "${SCRIPT_DIR}/lib/api/issue.sh"
source "${SCRIPT_DIR}/lib/api/sprint.sh"
source "${SCRIPT_DIR}/lib/api/comment.sh"
source "${SCRIPT_DIR}/lib/api/transition.sh"
source "${SCRIPT_DIR}/lib/api/fields.sh"

# Load utilities if available
[[ -f "${SCRIPT_DIR}/lib/util/retry.sh" ]]    && source "${SCRIPT_DIR}/lib/util/retry.sh"
[[ -f "${SCRIPT_DIR}/lib/util/parallel.sh" ]]  && source "${SCRIPT_DIR}/lib/util/parallel.sh"
[[ -f "${SCRIPT_DIR}/lib/util/cache.sh" ]]     && source "${SCRIPT_DIR}/lib/util/cache.sh"
[[ -f "${SCRIPT_DIR}/lib/team.sh" ]]           && source "${SCRIPT_DIR}/lib/team.sh"

# Load composite commands if available
for f in "${SCRIPT_DIR}"/lib/composite/*.sh; do
  [[ -f "$f" ]] && source "$f"
done

# ── Help ───────────────────────────────────────────────────────────────────────

cmd_help() {
  cat <<'EOF'
Usage: jira.sh <command> [args]

Low-level API commands:
  search <JQL> [limit]              Search issues (default limit: 50)
  get <ISSUE-KEY>                   Get full issue details
  sprints [state]                   List sprints (active|future|closed)
  sprint-issues <sprintId> [limit]  Get issues in a sprint (default limit: 100)
  comments <ISSUE-KEY>              List comments on an issue
  comment <body> <KEY...>           Add a comment to one or more issues
  move-to-sprint <sprintId> <KEY...> Move issue(s) to a sprint
  set-points <ISSUE-KEY> <points>   Set story points on an issue
  transitions <ISSUE-KEY>           Get available transitions
  transition <id> <KEY...>          Perform a transition on one or more issues
  close [comment] <KEY...>          Comment (optional) + close one or more issues

High-level composite commands:
  sprint-dashboard <team>           Sprint info + issues by status + workload + blockers
  standup-data <team>               Dashboard + recent updates + new bugs + comments
  bug-overview <team>               Bug triage data (untriaged, unassigned, blockers, new)
  carryover-report <team>           Not-done items with carryover context
  planning-data <team>              Full planning package (carryovers + backlog + bugs)
  issue-deep-dive <KEY>             Full issue + comments (ADF converted) + linked issues
  release-data <team> [version]     Release readiness (blockers, bugs, epics)
  team-activity <team>              Per-member sprint items + comment counts

Options:
  --stream                          Stream JSON Lines output (composite commands only)

Environment:
  JIRA_EMAIL       Override Jira email (default: Keychain account or git config user.email)
  JIRA_BOARD_ID    Override board ID (default: 7845)
EOF
}

# ── Dispatch ───────────────────────────────────────────────────────────────────

case "${1:-help}" in
  # Low-level API commands (backward-compatible)
  search)         cmd_search "${2:?JQL required}" "${3:-50}" ;;
  get)            cmd_get "${2:?ISSUE-KEY required}" ;;
  sprints)        cmd_sprints "${2:-active}" ;;
  sprint-issues)  cmd_sprint_issues "${2:?Sprint ID required}" "${3:-100}" ;;
  comments)       cmd_comments "${2:?ISSUE-KEY required}" ;;
  comment)        cmd_comment "${2:?Comment body required}" "${@:3}" ;;
  move-to-sprint) cmd_move_to_sprint "${2:?Sprint ID required}" "${@:3}" ;;
  set-points)     cmd_set_points "${2:?ISSUE-KEY required}" "${3:?Story points required}" ;;
  transitions)    cmd_transitions "${2:?ISSUE-KEY required}" ;;
  transition)     cmd_transition "${2:?Transition ID required}" "${@:3}" ;;
  close)          cmd_close "${@:2}" ;;

  # High-level composite commands
  sprint-dashboard)  cmd_sprint_dashboard "${@:2}" ;;
  standup-data)      cmd_standup_data "${@:2}" ;;
  bug-overview)      cmd_bug_overview "${@:2}" ;;
  carryover-report)  cmd_carryover_report "${@:2}" ;;
  planning-data)     cmd_planning_data "${@:2}" ;;
  issue-deep-dive)   cmd_issue_deep_dive "${@:2}" ;;
  release-data)      cmd_release_data "${@:2}" ;;
  team-activity)     cmd_team_activity "${@:2}" ;;
  my-board-data)     cmd_my_board_data "${@:2}" ;;
  my-bugs-data)      cmd_my_bugs_data "${@:2}" ;;
  my-standup-data)   cmd_my_standup_data "${@:2}" ;;
  epic-progress)     cmd_epic_progress "${@:2}" ;;
  pickup-data)       cmd_pickup_data "${@:2}" ;;

  help|--help|-h) cmd_help ;;
  *)              echo "Unknown command: $1" >&2; cmd_help >&2; exit 1 ;;
esac

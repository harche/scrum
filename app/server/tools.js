// Anthropic tool definitions for Claude — maps to bin/jira.sh and bin/gh-activity.sh

const TEAM_ENUM = ['Node Devices', 'Node Core'];

export const TOOLS = [
  // ── Jira Composite (read-only) ────────────────────────────────────────
  {
    name: 'sprint_dashboard',
    description: 'Get the current sprint dashboard: issues by status, team workload, blockers, and story points progress. Use for sprint status checks, team load reviews, or sprint review prep.',
    input_schema: {
      type: 'object',
      properties: {
        team: { type: 'string', enum: TEAM_ENUM, description: 'Team name' },
      },
      required: ['team'],
    },
  },
  {
    name: 'bug_overview',
    description: 'Get bug triage overview: untriaged bugs, unassigned bugs, release blocker proposals, and new bugs this week. Use for bug triage sessions.',
    input_schema: {
      type: 'object',
      properties: {
        team: { type: 'string', enum: TEAM_ENUM, description: 'Team name' },
      },
      required: ['team'],
    },
  },
  {
    name: 'standup_data',
    description: 'Get standup/grooming data: sprint status + issues grouped by assignee + blockers + recent activity + team workload. Use for standup prep.',
    input_schema: {
      type: 'object',
      properties: {
        team: { type: 'string', enum: TEAM_ENUM, description: 'Team name' },
      },
      required: ['team'],
    },
  },
  {
    name: 'issue_deep_dive',
    description: 'Get full details for a single Jira issue: description, comments (ADF converted), linked issues, available transitions. Use for investigating an issue, preparing briefings, or taking actions.',
    input_schema: {
      type: 'object',
      properties: {
        key: { type: 'string', description: 'Jira issue key (e.g., OCPNODE-1234 or OCPBUGS-5678)' },
      },
      required: ['key'],
    },
  },
  {
    name: 'carryover_report',
    description: 'Get carryover analysis: items not completed in the current sprint with context. Use for sprint planning prep.',
    input_schema: {
      type: 'object',
      properties: {
        team: { type: 'string', enum: TEAM_ENUM, description: 'Team name' },
      },
      required: ['team'],
    },
  },
  {
    name: 'planning_data',
    description: 'Get sprint planning data: carryovers, scheduled items, backlog, and unscheduled bugs. Use for sprint planning sessions.',
    input_schema: {
      type: 'object',
      properties: {
        team: { type: 'string', enum: TEAM_ENUM, description: 'Team name' },
      },
      required: ['team'],
    },
  },
  {
    name: 'release_data',
    description: 'Get release readiness data: blocker bugs, open bugs, and epic progress for a release version.',
    input_schema: {
      type: 'object',
      properties: {
        team: { type: 'string', enum: TEAM_ENUM, description: 'Team name' },
        version: { type: 'string', description: 'OCP version (e.g., "4.18"). If omitted, uses the latest.' },
      },
      required: ['team'],
    },
  },
  {
    name: 'epic_progress',
    description: 'Get progress on epics the current user contributes to in this sprint. Shows each epic with child issue breakdown.',
    input_schema: {
      type: 'object',
      properties: {
        team: { type: 'string', enum: TEAM_ENUM, description: 'Team name' },
      },
      required: ['team'],
    },
  },
  {
    name: 'my_board_data',
    description: 'Get the current user\'s sprint board: all issues assigned to them in the active sprint, grouped by status.',
    input_schema: {
      type: 'object',
      properties: {
        team: { type: 'string', enum: TEAM_ENUM, description: 'Team name' },
      },
      required: ['team'],
    },
  },
  {
    name: 'my_bugs_data',
    description: 'Get bugs assigned to the current user, sorted by severity and customer impact.',
    input_schema: {
      type: 'object',
      properties: {
        team: { type: 'string', enum: TEAM_ENUM, description: 'Team name' },
      },
      required: ['team'],
    },
  },
  {
    name: 'pickup_data',
    description: 'Find unassigned work: sprint items and bugs available for pickup.',
    input_schema: {
      type: 'object',
      properties: {
        team: { type: 'string', enum: TEAM_ENUM, description: 'Team name' },
      },
      required: ['team'],
    },
  },
  {
    name: 'my_standup_data',
    description: 'Get personal standup data: items assigned to the current user with recent comments.',
    input_schema: {
      type: 'object',
      properties: {
        team: { type: 'string', enum: TEAM_ENUM, description: 'Team name' },
      },
      required: ['team'],
    },
  },

  // ── Jira Low-Level (read) ─────────────────────────────────────────────
  {
    name: 'jira_transitions',
    description: 'Get available status transitions for a Jira issue. Call this before transitioning to find valid transition IDs.',
    input_schema: {
      type: 'object',
      properties: {
        issue_key: { type: 'string', description: 'Jira issue key' },
      },
      required: ['issue_key'],
    },
  },
  {
    name: 'jira_search',
    description: 'Search Jira issues using JQL. Returns JSON with matching issues.',
    input_schema: {
      type: 'object',
      properties: {
        jql: { type: 'string', description: 'JQL query string' },
        limit: { type: 'number', description: 'Max results (default: 50)' },
      },
      required: ['jql'],
    },
  },

  // ── Jira Write Operations ─────────────────────────────────────────────
  {
    name: 'jira_transition',
    description: 'Transition a Jira issue to a new status. IMPORTANT: Always confirm with the user before calling this. Use jira_transitions first to get valid transition IDs.',
    input_schema: {
      type: 'object',
      properties: {
        transition_id: { type: 'string', description: 'Transition ID (from jira_transitions)' },
        issue_key: { type: 'string', description: 'Jira issue key' },
      },
      required: ['transition_id', 'issue_key'],
    },
  },
  {
    name: 'jira_comment',
    description: 'Add a comment to a Jira issue. IMPORTANT: Always draft the comment text and confirm with the user before posting.',
    input_schema: {
      type: 'object',
      properties: {
        body: { type: 'string', description: 'Comment text' },
        issue_key: { type: 'string', description: 'Jira issue key' },
      },
      required: ['body', 'issue_key'],
    },
  },
  {
    name: 'jira_set_points',
    description: 'Set story points on a Jira issue. Confirm with the user first.',
    input_schema: {
      type: 'object',
      properties: {
        issue_key: { type: 'string', description: 'Jira issue key' },
        points: { type: 'number', description: 'Story points value' },
      },
      required: ['issue_key', 'points'],
    },
  },
  {
    name: 'jira_set_field',
    description: 'Set a custom field value on a Jira issue. Confirm with the user first.',
    input_schema: {
      type: 'object',
      properties: {
        issue_key: { type: 'string', description: 'Jira issue key' },
        field_id: { type: 'string', description: 'Custom field ID (e.g., customfield_10028)' },
        value: { type: 'string', description: 'Field value (string, number, or JSON)' },
      },
      required: ['issue_key', 'field_id', 'value'],
    },
  },
  {
    name: 'jira_close',
    description: 'Close a Jira issue with an optional comment. Confirm with the user first.',
    input_schema: {
      type: 'object',
      properties: {
        issue_key: { type: 'string', description: 'Jira issue key' },
        comment: { type: 'string', description: 'Optional closing comment' },
      },
      required: ['issue_key'],
    },
  },

  // ── GitHub ────────────────────────────────────────────────────────────
  {
    name: 'team_prs',
    description: 'Get GitHub PR activity for all team members. Shows authored, reviewed, and commented PRs.',
    input_schema: {
      type: 'object',
      properties: {
        roster_file: { type: 'string', description: 'Path to team roster JSON (e.g., config/team-roster-dra.json)' },
        since: { type: 'string', description: 'Date filter (e.g., "7 days ago"). Defaults to 7 days.' },
      },
      required: ['roster_file'],
    },
  },
  {
    name: 'member_prs',
    description: 'Get GitHub activity for a specific team member: authored PRs, reviews, and issues.',
    input_schema: {
      type: 'object',
      properties: {
        handle: { type: 'string', description: 'GitHub handle' },
        since: { type: 'string', description: 'Date filter. Defaults to 7 days.' },
      },
      required: ['handle'],
    },
  },
  {
    name: 'my_prs',
    description: 'Get the user\'s open PRs and PRs requesting their review.',
    input_schema: {
      type: 'object',
      properties: {
        handle: { type: 'string', description: 'GitHub handle' },
      },
      required: ['handle'],
    },
  },
  {
    name: 'my_issues',
    description: 'Get the user\'s GitHub issues: authored, assigned, and recently commented.',
    input_schema: {
      type: 'object',
      properties: {
        handle: { type: 'string', description: 'GitHub handle' },
      },
      required: ['handle'],
    },
  },
  {
    name: 'review_queue',
    description: 'Get PRs awaiting the user\'s review, prioritized by age.',
    input_schema: {
      type: 'object',
      properties: {
        handle: { type: 'string', description: 'GitHub handle' },
      },
      required: ['handle'],
    },
  },
];

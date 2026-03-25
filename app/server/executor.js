import { execFile } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(__dirname, '../..');
const JIRA_SH = path.join(PROJECT_ROOT, 'bin/jira.sh');
const GH_ACTIVITY_SH = path.join(PROJECT_ROOT, 'bin/gh-activity.sh');

const TIMEOUT_MS = 120_000;

function exec(cmd, args) {
  return new Promise((resolve) => {
    execFile(cmd, args, {
      cwd: PROJECT_ROOT,
      timeout: TIMEOUT_MS,
      maxBuffer: 10 * 1024 * 1024,
      env: process.env,
    }, (err, stdout, stderr) => {
      if (stderr) console.error(`[executor stderr] ${stderr.trim()}`);
      if (err) {
        resolve({
          content: [{ type: 'text', text: err.message + (stderr ? `\n${stderr}` : '') }],
          isError: true,
        });
      } else {
        resolve({
          content: [{ type: 'text', text: stdout }],
          isError: false,
        });
      }
    });
  });
}

// Single registry: tool name → { exec: (params) => [cmd, args], richType?: string }
const TOOLS = {
  // Jira composite (read-only) — all have rich UI renderers
  sprint_dashboard:  { exec: (p) => [JIRA_SH, ['sprint-dashboard', p.team]], richType: 'sprint_dashboard' },
  bug_overview:      { exec: (p) => [JIRA_SH, ['bug-overview', p.team]], richType: 'bug_overview' },
  standup_data:      { exec: (p) => [JIRA_SH, ['standup-data', p.team]], richType: 'standup_data' },
  issue_deep_dive:   { exec: (p) => [JIRA_SH, ['issue-deep-dive', p.key]], richType: 'issue_deep_dive' },
  carryover_report:  { exec: (p) => [JIRA_SH, ['carryover-report', p.team]], richType: 'carryover_report' },
  planning_data:     { exec: (p) => [JIRA_SH, ['planning-data', p.team]], richType: 'planning_data' },
  release_data:      { exec: (p) => { const a = ['release-data', p.team]; if (p.version) a.push(p.version); return [JIRA_SH, a]; }, richType: 'release_data' },
  epic_progress:     { exec: (p) => [JIRA_SH, ['epic-progress', p.team]], richType: 'epic_progress' },
  my_board_data:     { exec: (p) => [JIRA_SH, ['my-board-data', p.team]], richType: 'my_board' },
  my_bugs_data:      { exec: (p) => [JIRA_SH, ['my-bugs-data', p.team]], richType: 'my_bugs' },
  pickup_data:       { exec: (p) => [JIRA_SH, ['pickup-data', p.team]], richType: 'pickup_data' },
  my_standup_data:   { exec: (p) => [JIRA_SH, ['my-standup-data', p.team]], richType: 'my_standup' },

  // Jira low-level (read, no rich UI)
  jira_transitions:  { exec: (p) => [JIRA_SH, ['transitions', p.issue_key]] },
  jira_search:       { exec: (p) => { const a = ['search', p.jql]; if (p.limit) a.push(String(p.limit)); return [JIRA_SH, a]; } },

  // Jira write operations (no rich UI)
  jira_transition:   { exec: (p) => [JIRA_SH, ['transition', p.transition_id, p.issue_key]] },
  jira_comment:      { exec: (p) => [JIRA_SH, ['comment', p.body, p.issue_key]] },
  jira_set_points:   { exec: (p) => [JIRA_SH, ['set-points', p.issue_key, String(p.points)]] },
  jira_set_field:    { exec: (p) => [JIRA_SH, ['set-field', p.issue_key, p.field_id, p.value]] },
  jira_close:        { exec: (p) => { const a = ['close']; if (p.comment) a.push(p.comment); a.push(p.issue_key); return [JIRA_SH, a]; } },

  // GitHub (all have rich UI)
  team_prs:          { exec: (p) => { const a = ['team-prs', p.roster_file]; if (p.since) a.push(p.since); return [GH_ACTIVITY_SH, a]; }, richType: 'team_prs' },
  member_prs:        { exec: (p) => { const a = ['member-prs', p.handle]; if (p.since) a.push(p.since); return [GH_ACTIVITY_SH, a]; }, richType: 'member_prs' },
  my_prs:            { exec: (p) => [GH_ACTIVITY_SH, ['my-prs', p.handle]], richType: 'my_prs' },
  my_issues:         { exec: (p) => [GH_ACTIVITY_SH, ['my-issues', p.handle]], richType: 'my_issues' },
  review_queue:      { exec: (p) => [GH_ACTIVITY_SH, ['review-queue', p.handle]], richType: 'review_queue' },
};

export async function executeTool(toolName, toolInput) {
  const tool = TOOLS[toolName];
  if (!tool) {
    return {
      content: [{ type: 'text', text: `Unknown tool: ${toolName}` }],
      isError: true,
    };
  }
  const [cmd, args] = tool.exec(toolInput);
  return exec(cmd, args);
}

export function detectRichType(toolName) {
  return TOOLS[toolName]?.richType || null;
}

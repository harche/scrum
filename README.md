# Scrum Master Workspace

Claude Code slash commands for managing sprints, standups, and daily work on the OpenShift Node team.

## Setup

Requires:
- [Claude Code](https://claude.com/claude-code)
- Jira API token (stored in macOS Keychain as `JIRA_API_TOKEN`)
- `JIRA_EMAIL` environment variable
- [GitHub CLI](https://cli.github.com/) (`gh`) authenticated

## Commands

### Scrum Master

| Command | Purpose |
|---------|---------|
| `/sprint-status` | Current sprint dashboard |
| `/standup` | Weekly standup prep |
| `/standup-github` | GitHub activity for all team members |
| `/sprint-plan` | Sprint planning preparation |
| `/sprint-review` | Sprint review summary |
| `/bug-triage` | Bug triage session |
| `/carryovers` | Carryover analysis |
| `/team-load` | Workload distribution |
| `/team-member <name>` | Individual Jira activity |
| `/team-member-github <name>` | Individual GitHub activity |
| `/investigate <KEY>` | Deep dive on a Jira issue |
| `/release-check` | Release readiness check |

### Team Member

| Command | Purpose |
|---------|---------|
| `/my-board` | My sprint items by status |
| `/my-bugs` | My bugs by severity and age |
| `/my-epics` | Epic progress I'm contributing to |
| `/my-standup` | Personal standup talking points |
| `/my-prs` | My open PRs and review requests |
| `/my-github-issues` | My GitHub issues |
| `/review-queue` | PRs awaiting my review |
| `/pickup` | Find unassigned work |
| `/update <KEY>` | Update an issue (comment, transition, points) |
| `/blocker <KEY>` | Flag/unflag a blocker |
| `/briefing <KEY>` | Get up to speed on an issue |
| `/handoff <KEY>` | Prepare a handoff summary |

### Meta

| Command | Purpose |
|---------|---------|
| `/self-improvement` | Review session errors and propose workspace fixes |

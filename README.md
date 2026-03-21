# Scrum Master Workspace

Claude Code slash commands for managing sprints, standups, and daily work on the OpenShift Node team.

Every command is an interactive workflow — after showing results, it offers contextual follow-up actions based on the actual API state (available Jira transitions, GitHub PR review/CI status, field values). Pick an item, act on it, and keep going without leaving the flow.

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

## How It Works

Each command follows a **show → select → act → loop** pattern:

1. **Show** — Fetches data from Jira/GitHub APIs and presents it in tables
2. **Select** — Asks which item to act on (numbered for easy reference)
3. **Act** — Queries the API for available actions on that item:
   - **Jira:** Fetches actual transitions (`bin/jira.sh transitions`), checks field state (story points, blocked status, assignee, customer cases)
   - **GitHub:** Fetches PR state (`gh pr view --json`), checks review decision, CI status, merge readiness
4. **Loop** — After each action, re-fetches state and offers the next set of actions. Continues until you're done.

The options you see are always driven by the current state — if a Jira transition isn't available, it won't appear. If a PR is approved with passing checks, "Merge" is offered. No stale menus.

# Scrum Master GoGo

<p align="center">
  <img src="assets/gogo1.jpg" height="300" />
  <img src="assets/gogo.jpg" height="300" />
</p>

<p align="center"><i>"Scrum Master GoGo naam hai mera... carryovers nikal ke gotiyaan khelta hoon main!"</i></p>

---

Claude Code slash commands for managing sprints, standups, and daily work on the OpenShift Node team.

Every command is an interactive workflow — after showing results, it offers contextual follow-up actions based on the actual API state (available Jira transitions, GitHub PR review/CI status, field values). Pick an item, act on it, and keep going without leaving the flow.

## Setup

Requires:
- [Claude Code](https://claude.com/claude-code)
- Jira API token (stored in macOS Keychain as `JIRA_API_TOKEN`)
- `JIRA_EMAIL` environment variable
- [GitHub CLI](https://cli.github.com/) (`gh`) authenticated
- `bats-core` for tests (`brew install bats-core`)

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

1. **Show** — Calls a single composite command that parallelizes all API calls internally and returns pre-computed JSON
2. **Select** — Asks which item to act on (numbered for easy reference)
3. **Act** — Queries the API for available actions on that item:
   - **Jira:** Fetches actual transitions, checks field state (story points, blocked status, assignee, customer cases)
   - **GitHub:** Fetches PR state, checks review decision, CI status, merge readiness
4. **Loop** — After each action, re-fetches state and offers the next set of actions. Continues until you're done.

The options you see are always driven by the current state — if a Jira transition isn't available, it won't appear. If a PR is approved with passing checks, "Merge" is offered. No stale menus.

## Architecture

```
bin/
  jira.sh                    Thin dispatcher — sources modular libraries
  gh-activity.sh             GitHub activity (GraphQL batching)
  gh-discussion.sh           GitHub Discussions publish/comment
  lib/
    core.sh                  Auth, HTTP, constants, logging
    team.sh                  Team config resolution (sprint filter, roster, components)
    api/
      issue.sh               cmd_search, cmd_get (with optional field limiting)
      sprint.sh              cmd_sprints, cmd_sprint_issues (with optional field limiting)
      comment.sh             cmd_comments, cmd_comment
      transition.sh          cmd_transitions, cmd_transition, cmd_close
      fields.sh              cmd_set_points, cmd_move_to_sprint
      health.sh              cmd_health_check (field metadata validation)
    composite/
      sprint-dashboard.sh    Sprint info + issues by status + workload + blockers
      standup-data.sh        Dashboard + updates + bugs + comments + activity
      bug-overview.sh        All open bugs → categorized in Python (3 queries)
      carryover-report.sh    Not-done items with carryover context
      planning-data.sh       Carryovers + scheduled + backlog + bugs
      issue-deep-dive.sh     Full issue + comments (ADF→text) + transitions
      release-data.sh        All bugs → blockers categorized in Python (2 queries)
      team-activity.sh       Per-member sprint items + comment counts
      my-board-data.sh       Sprint items filtered to current user
      my-bugs-data.sh        User's bugs with categories
      my-standup-data.sh     Standup data filtered to current user
      epic-progress.sh       Bulk epic + children fetch (2 queries)
      pickup-data.sh         Unassigned sprint items + bugs (2 queries)
    util/
      adf.py                 ADF-to-text converter (standalone)
      parallel.sh            Background job management + streaming
      retry.sh               Exponential backoff + rate limiting
      cache.sh               Sprint caching (5-min TTL)
config/
  team-roster-dra.json       Node Devices (DRA) team roster
  team-roster-core.json      Node Core team roster
tests/
  fixtures/                  Mock API responses
  test-core.bats             Auth, constants, utilities
  test-api.bats              Low-level API commands
  test-adf.bats              ADF-to-text conversion
  test-team.bats             Team config resolution
  test-parallel.bats         Job management
  test-composite.bats        All composite commands
  run-tests.sh               Test runner
```

Every slash command calls exactly one composite script (or two in parallel for Jira+GitHub commands). The composites handle all API parallelization, data grouping, ADF conversion, and filtering. Claude renders the JSON output directly — zero post-processing.

## API Efficiency

Both Jira and GitHub calls are optimized to minimize API usage:

**GitHub** — `gh-activity.sh` uses GraphQL batching. Each command makes a single GraphQL call (instead of 2-3 REST calls). `team-prs` batches members in groups of 6, reducing a 16-member team from 48 REST calls to 3 GraphQL calls. Uses the 5,000 points/hr GraphQL budget instead of the tight 30/min search rate limit.

**Jira** — Composite commands fetch broader datasets and categorize in Python rather than making narrow parallel queries. `bug-overview` went from 7 queries to 3; `epic-progress` from 2N to 2; `release-data` from 4 to 2. API functions accept optional `fields` parameters to limit payload size.

**Health monitoring** — `bin/jira.sh health-check` validates all custom field IDs against Jira metadata. Composite commands include shape assertions and canary warnings on stderr to detect field format drift at runtime.

## Tests

```bash
# Run all tests
bats tests/test-*.bats

# Run a specific test file
bats tests/test-composite.bats
```

92 tests covering: core utilities, API commands, ADF conversion, team config, parallel execution, and all 13 Jira composite commands.

```bash
# Validate Jira field mappings haven't drifted
bin/jira.sh health-check
```

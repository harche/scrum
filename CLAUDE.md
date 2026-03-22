# Scrum Master Workspace — OpenShift Node Team

You are assisting a Scrum Master for sub-teams within the OpenShift Node team at Red Hat.

## Team Selection

All slash commands that target a specific sprint must start by asking which team using `AskUserQuestion`:
- **"Node Devices (DRA)"** or **"Node Core"**

Based on the selection, use the corresponding config from the table below:

| Config | Node Devices (DRA) | Node Core |
|--------|-------------------|-----------|
| Sprint filter | "Node Devices" | "Node Core" |
| Roster file | `config/team-roster-dra.json` | `config/team-roster-core.json` |
| Bug components | `"Node / Device Manager", "Node / Instaslice-operator"` | All Node components (see below) |
| Backlog keywords | DRA, DAS, Instaslice, device | (broad — all OCPNODE backlog) |

## Jira API

Always use the REST API helper at `bin/jira.sh` for Jira operations (not `acli`).

```bash
# Search issues (returns JSON)
bin/jira.sh search '<JQL>'

# Get a single issue (all fields)
bin/jira.sh get <ISSUE-KEY>

# List sprints (state: active|future|closed, default: active)
bin/jira.sh sprints [state]

# Get issues in a sprint
bin/jira.sh sprint-issues <sprintId>

# List comments on an issue
bin/jira.sh comments <ISSUE-KEY>

# Move issue(s) to a sprint
bin/jira.sh move-to-sprint <sprintId> <ISSUE-KEY> [<ISSUE-KEY>...]

# Set story points on an issue
bin/jira.sh set-points <ISSUE-KEY> <points>

# Get available transitions for an issue
bin/jira.sh transitions <ISSUE-KEY>

# Perform a transition on one or more issues
bin/jira.sh transition <transitionId> <ISSUE-KEY> [<ISSUE-KEY>...]

# Close one or more issues (optional comment + transition to Closed)
bin/jira.sh close [comment] <ISSUE-KEY> [<ISSUE-KEY>...]

# Add a comment to one or more issues
bin/jira.sh comment <body> <ISSUE-KEY> [<ISSUE-KEY>...]
```

All output is JSON. `bin/jira.sh` uses the Agile REST API (`/rest/agile/1.0/`) for sprint and sprint-issues queries, and REST API v3 (`/rest/api/3/`) for everything else.

**ADF format:** API v3 returns `description` and comment `body` fields in Atlassian Document Format (ADF). Use the standalone converter: `echo '<adf-json>' | python3 bin/lib/util/adf.py` (also supports `--field`, `--comments`, `--issues` modes).

### High-Level Composite Commands

**Prefer composite commands over multiple low-level calls.** They parallelize internally and return pre-computed JSON:

```bash
# Sprint dashboard — issues by status, workload, blockers (serves /sprint-status, /team-load, /sprint-review)
bin/jira.sh sprint-dashboard <team>

# Standup data — dashboard + updates + bugs + comments + activity (serves /standup, /team-member)
bin/jira.sh standup-data <team>

# Bug overview — untriaged, unassigned, blockers, escalations, new (serves /bug-triage)
bin/jira.sh bug-overview <team>

# Carryover report — not-done items with context (serves /carryovers)
bin/jira.sh carryover-report <team>

# Planning data — carryovers + scheduled + backlog + unscheduled bugs (serves /sprint-plan)
bin/jira.sh planning-data <team>

# Issue deep dive — full issue + comments (ADF converted) + linked issues + transitions (serves /investigate, /briefing, /handoff, /update, /blocker)
bin/jira.sh issue-deep-dive <KEY>

# Release data — blockers, open bugs, epics for a version (serves /release-check)
bin/jira.sh release-data <team> [version]

# Team activity — per-member sprint items + comment counts (serves /standup, /team-member)
bin/jira.sh team-activity <team>

# My board — sprint items filtered to current user (serves /my-board)
bin/jira.sh my-board-data <team>

# My bugs — bugs assigned to current user (serves /my-bugs)
bin/jira.sh my-bugs-data <team>

# My standup — standup data filtered to current user (serves /my-standup, Jira side)
bin/jira.sh my-standup-data <team>

# Epic progress — epics I'm contributing to with children progress (serves /my-epics)
bin/jira.sh epic-progress <team>

# Pickup — all available unassigned work (serves /pickup)
bin/jira.sh pickup-data <team>
```

`<team>` accepts: `"Node Devices"`, `"Node Core"`, `"dra"`, `"core"` (case-sensitive).

### GitHub Activity Commands

`bin/gh-activity.sh` provides composite GitHub commands:

```bash
bin/gh-activity.sh my-prs <handle>         # My PRs + review requests (serves /my-prs)
bin/gh-activity.sh my-issues <handle>      # My GitHub issues (serves /my-github-issues)
bin/gh-activity.sh review-queue <handle>   # PRs awaiting my review (serves /review-queue)
bin/gh-activity.sh team-prs <roster-file>  # All members' activity (serves /standup-github)
bin/gh-activity.sh member-prs <handle>     # One member's activity (serves /team-member-github)
```

### Architecture

```
bin/jira.sh              — Thin dispatcher (sources all modules)
bin/gh-activity.sh       — GitHub activity composite commands
bin/gh-discussion.sh     — GitHub Discussions publish/comment
bin/lib/core.sh          — Auth, HTTP, constants, logging
bin/lib/team.sh          — Team config resolution
bin/lib/api/*.sh         — Low-level API commands (issue, sprint, comment, transition, fields)
bin/lib/composite/*.sh   — High-level Jira composite commands
bin/lib/util/adf.py      — ADF-to-text converter
bin/lib/util/parallel.sh — Background job management + streaming
bin/lib/util/retry.sh    — Exponential backoff + rate limiting
bin/lib/util/cache.sh    — Sprint caching (5-min TTL)
tests/                   — bats-core tests (run: bats tests/test-*.bats)
```

## Board & Sprint Info

- **Board ID:** 7845 (Node board). Sprint discovery uses the Agile API (`/rest/agile/1.0/board/{id}/sprint`), which returns sprints across linked boards.
- **Sprint naming patterns:** `OCP Node Core Sprint N`, `OCP Node Devices Sprint N`, `OCP Kueue Sprint N`
- **Jira projects:** OCPNODE (epics/stories/tasks), OCPBUGS (bugs)
- **Jira URL format:** `https://redhat.atlassian.net/browse/{KEY}`

## Team Discovery

**Never hardcode team member names or emails.** Discover dynamically:
```bash
bin/jira.sh sprint-issues <sprintId> | python3 -c "
import sys, json
data = json.load(sys.stdin)
team = set()
for i in data.get('issues', []):
    a = i['fields'].get('assignee')
    if a:
        team.add(a['displayName'])
print(', '.join(sorted(team)))
"
```

## Version Discovery

**Never hardcode OCP versions.** Accept as argument or query dynamically:
```bash
bin/jira.sh search 'project = OCPNODE AND fixVersion is not EMPTY AND status not in (Closed, Done) ORDER BY fixVersion DESC' | python3 -c "
import sys, json
versions = set()
for i in json.load(sys.stdin).get('issues', []):
    fv = i['fields'].get('fixVersions', [])
    for v in fv:
        versions.add(v['name'])
for v in sorted(versions): print(v)
"
```

## Meeting Cadence

- **Weekly (Tuesdays 9:00 AM ET):** Node Devices Team Standup/Grooming/Planning
- **Sprint boundaries:** Node Devices Planning for Sprint N (1 hour)
- **Weekly (Wednesdays 8:00 AM ET):** Node Core Scrum/Grooming/Bug Scrub

## Key Jira Fields

| Field | Custom Field ID |
|-------|----------------|
| Sprint | customfield_10020 |
| Story Points | customfield_10028 |
| Epic Link | customfield_10014 |
| Target Version | customfield_10855 |
| Release Blocker | customfield_10847 |
| SFDC Cases Counter | customfield_10978 |
| SFDC Cases Links | customfield_10979 |
| Severity | customfield_10840 |
| Blocked | customfield_10517 |
| Blocked Reason | customfield_10483 |

## Node Components (for JQL filtering)

Node, Node / CRI-O, Node / Kubelet, Node / CPU manager, Node / Memory manager,
Node / Topology manager, Node / Numa aware Scheduling, Node / Device Manager,
Node / Pod resource API, Node / Node Problem Detector, Node / Kueue, Node / Instaslice-operator

## Bug Statuses

NEW → To Do → ASSIGNED → POST → Modified → ON_QA → Verified → CLOSED

## Sprint Planning Workflow

Recommended sequence for sprint planning prep:

1. **`/sprint-status`** — Quick health check on the current sprint
2. **`/carryovers`** — Identify what didn't finish and decide keep vs. descope
3. **`/team-load`** — Check capacity across the team
4. **`/sprint-plan`** — Full planning package (wrap-up, scheduled items, backlog, bugs, capacity)
5. **`/bug-triage`** — Review and schedule open bugs
6. **`/investigate <KEY>`** — Deep dive on specific items as needed

## Slash Commands

### Scrum Master Commands

| Command | Purpose | Source |
|---------|---------|--------|
| `/sprint-status` | Current sprint dashboard | Jira |
| `/standup` | Weekly standup prep (Tuesdays) | Jira |
| `/standup-github` | GitHub activity for all team members | GitHub |
| `/sprint-plan` | Sprint planning preparation | Jira |
| `/bug-triage` | Bug triage session | Jira |
| `/carryovers` | Carryover analysis | Jira |
| `/team-load` | Workload distribution | Jira |
| `/investigate [KEY]` | Deep dive on a single issue | Jira |
| `/team-member <name>` | Individual Jira activity summary | Jira |
| `/team-member-github <name>` | Individual GitHub activity summary | GitHub |
| `/release-check [version]` | Release readiness check | Jira |
| `/sprint-review` | Sprint review summary | Jira |

### Team Member Commands

| Command | Purpose | Source | Asks Team? |
|---------|---------|--------|------------|
| `/my-board` | My assigned sprint items by status | Jira | Yes |
| `/my-bugs` | My bugs sorted by severity, age, customer impact | Jira | Yes |
| `/my-epics` | Progress on epics I'm contributing to | Jira | Yes |
| `/pickup` | Find unassigned work to grab | Jira | Yes |
| `/update <KEY>` | Quick update: comment, transition, set points | Jira | No |
| `/blocker <KEY>` | Flag/unflag a blocker on an issue | Jira | No |
| `/my-prs` | My open PRs + PRs requesting my review | GitHub | No |
| `/my-github-issues` | My GitHub issues (authored, assigned, commented) | GitHub | No |
| `/review-queue` | PRs waiting for my review, prioritized | GitHub | No |
| `/my-standup` | Personal standup talking points (done/doing/blocked) | Both | Yes |
| `/briefing <KEY>` | Get up to speed on an issue fast | Both | No |
| `/handoff <KEY>` | Prepare a handoff summary for an issue | Both | No |

## Output Conventions

- Always include clickable Jira URLs: `https://redhat.atlassian.net/browse/{KEY}`
- Present tabular data in markdown tables
- **Enumerate all rows** in tables and lists with a `#` column (1, 2, 3...) so items can be referenced by number (e.g., "item 3", "team member 2") instead of copying strings
- **Write operations require explicit confirmation.** Before any state-changing action (commenting on Jira/GitHub, transitioning issue status, creating/editing issues, posting on PRs), always:
  1. Draft the content and show it to the user
  2. Use the `AskUserQuestion` tool to ask for confirmation (e.g., "Post this comment to OCPNODE-1234?")
  3. Only execute the action if the user confirms
- When showing sprint status, group items by status and highlight blockers
- **Interactive lists:** When presenting lists of Jira issues or GitHub items (bugs, PRs, stories, etc.), go through categories one at a time. For each category:
  1. Show the table of items
  2. Use `AskUserQuestion` to ask which item(s) to deal with (list each as an option, plus "Skip" to move on)
  3. If the user picks an item, investigate/act on it before continuing
  4. After handling (or skipping), move to the next category
  Do NOT dump all categories at once.

## Contextual Actions (Generative UI)

Every slash command ends with a dynamic action menu driven by the actual API state — never hardcoded option lists. This turns each command into an interactive workflow where the user can take follow-up actions without leaving the flow.

### Pattern for Jira Items

After presenting results, for any item the user selects:

1. **Fetch available transitions:** `bin/jira.sh transitions <KEY>` — returns the exact transitions available for that issue's current status
2. **Check field state** from the already-fetched issue:
   - `customfield_10028` (Story Points): offer "Set points" or "Update points"
   - `customfield_10517` (Blocked): offer "Unflag blocker" or "Flag as blocked"
   - `customfield_10847` (Release Blocker): offer blocker status change
   - `assignee`: offer "Reassign" or "Assign"
   - `customfield_10978` (SFDC Cases): offer "View customer cases"
3. **Build `AskUserQuestion` options dynamically** — transitions by name + field-based options + "Add a comment" + "Done"
4. **Action loop:** After executing an action, re-fetch the issue and transitions, then offer the next set of actions. Continue until the user picks "Done".

### Pattern for GitHub Items (PRs/Issues)

After presenting results, for any PR/issue the user selects:

1. **Fetch PR state:** `gh pr view <URL> --json state,reviewDecision,statusCheckRollup,isDraft,mergeable`
2. **Build options from state:**
   - Approved + checks passing + mergeable → "Merge", "Squash and merge"
   - Checks failing → "View failing checks", "Re-run checks"
   - No reviews → "Request review from..." (list roster handles)
   - Draft → "Mark ready for review"
   - Changes requested → "View review comments"
   - Always: "Add a comment", "Open in browser", "Done"
3. **Action loop:** Re-fetch state after each action, offer updated options.

### Key Principle

The API is the source of truth for what's possible. Options shown to the user reflect the **actual current state** — if a transition isn't available, it doesn't appear. If a PR is already approved, "Merge" is offered. This prevents stale or impossible actions.

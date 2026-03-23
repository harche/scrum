Generate my personal standup talking points — what I did, what I'm doing, and what's blocking me.

## Steps

Run these in parallel:

1. **Jira data:**
   `bin/jira.sh my-standup-data "<team>"`

   Returns pre-filtered to my items: `sprint` (name, daysElapsed, daysTotal), `done[]`, `inProgress[]`, `blocked[]` (with blockedReason), `upNext[]`, `recentComments[]` (plain text), `summary` (counts).

   **Team Selection:** Use `AskUserQuestion` to ask which team first.

2. **GitHub PRs:**
   `bin/gh-activity.sh my-prs harche`

   Returns: `authoredOpen[]`, `authoredMerged[]`, `reviewRequested[]`.

## Output

### My Standup — [Date]
Sprint: `sprint.name` | Day `sprint.daysElapsed` of `sprint.daysTotal`

### Done (since last standup)
- From `done[]` (Jira items)
- From `authoredMerged[]` (merged PRs)

### In Progress
- From `inProgress[]` (Jira items with status)
- From `authoredOpen[]` (open PRs with reviewDecision)

### Blocked
- From `blocked[]` — show each item's `blockedReason`
- PRs from `authoredOpen[]` with failing CI or changes requested

### Up Next
- From `upNext[]` (To Do items)
- From `reviewRequested[]` (PRs needing my review)

### Talking Points
Auto-generated 3-5 bullet points from the data above.

Always include clickable Jira and GitHub URLs.

### Contextual Actions (Dynamic)

Use `AskUserQuestion` with options based on data:
- If blocked items → "Unblock [KEY]" for each
- If To Do items → "Start working on [KEY]"
- If PRs approved → "Merge [PR title]"
- "Act on a Jira item" / "Act on a GitHub PR" / "Done"

When user picks a Jira item:
1. Fetch transitions: `bin/jira.sh transitions <KEY>`
2. Build dynamic options, execute with confirmation, action loop.

When user picks a GitHub PR:
1. Fetch state: `gh pr view <URL> --json state,reviewDecision,statusCheckRollup,isDraft,mergeable`
2. Build dynamic options, execute with confirmation, action loop.

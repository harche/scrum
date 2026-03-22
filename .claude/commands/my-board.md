Show my personal sprint board — all issues assigned to me in the current sprint.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md).

2. **Fetch my board data:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh my-board-data "<team>"`

   Returns pre-filtered JSON: `sprint` (name, dates, daysRemaining), `summary` (total, done, inProgress, toDo, totalPoints, donePoints), `byStatus` (my items grouped by status), `flags` (blocked, no points, at-risk items).

3. Render the output directly from the returned JSON.

## Output

### My Board — `sprint.name`
Days remaining: `sprint.daysRemaining` of `sprint.daysTotal` | Points: `summary.donePoints`/`summary.totalPoints`

### Summary
From `summary`: total items, done, in progress, to do, points.

### My Items by Status

Tables from `byStatus` groups. Each table: #, Key (clickable), Type, Summary, Pts.

**Done/Closed** (from `byStatus.done`)
**In Progress / Code Review** (from `byStatus.inProgress` + `byStatus.codeReview`)
**To Do / New** (from `byStatus.toDo`)

### Flags
From `flags` array — each has `key`, `summary`, `reason`.

Always include clickable Jira URLs.

### Contextual Actions (Dynamic)

Use `AskUserQuestion`: "Which item would you like to act on?" with item numbers + "Done".

When user picks an item:
1. Fetch transitions: `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh transitions <KEY>`
2. Build dynamic options from transitions + state (points, blocked, assignee)
3. Execute with confirmation. Action loop until done.

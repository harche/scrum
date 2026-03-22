Show the current sprint dashboard.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team name for the composite command.

2. **Fetch all sprint data in one call:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprint-dashboard "<team>"`

   This returns a single JSON blob with: `sprint` (id, name, dates, daysElapsed, daysTotal, daysRemaining), `summary` (counts by status, points), `byStatus` (issues grouped by status), `blockers`, `atRisk`, `teamWorkload`, `roster`.

3. Parse the JSON and produce a dashboard.

### Sprint Header
- Sprint name, start date, end date, days remaining

### Summary Counts
Table with: Total items, Done/Closed, In Progress, Code Review, To Do/New, Bugs vs Stories

### Items by Status
Group items into tables by status category (from `byStatus`):
- **Done/Closed** (collapsed count only unless asked)
- **In Progress** — show key, summary, assignee, story points
- **Code Review** — show key, summary, assignee
- **To Do / New** — show key, summary, assignee, priority
- **Blocked** — items from `blockers` array, show with blocked reason

### At Risk
Items from `atRisk` array:
- Items still in To Do with < 3 days remaining
- Items with no assignee
- Bugs with Undefined priority (untriaged)

### Team Workload
Table from `teamWorkload`: assignee, # items in progress, # items done, # items total

### Contextual Actions (Dynamic)

After presenting the dashboard, use `AskUserQuestion` to ask: "Which item would you like to act on?" with item numbers from the In Progress, Code Review, To Do, and Blocked tables as options, plus "Run /sprint-plan", "Run /bug-triage", "Done (no actions needed)".

When the user picks an item, resolve that item's available actions from the API:

1. **Fetch available transitions:** `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh transitions <SELECTED-KEY>`
2. **Check current state:**
   - Has story points? → offer "Update story points" : "Set story points"
   - Is blocked? → offer "Unflag blocker" : "Flag as blocked"
   - Has assignee? → offer "Reassign" : "Assign"

3. **Build dynamic options** for `AskUserQuestion`: "What would you like to do with [KEY]?"
   - List each available transition by name (from the transitions API)
   - Include the state-based options from step 2
   - Always include: "Add a comment", "Investigate (deep dive)", "Done (back to dashboard)"

4. **Execute the chosen action** (with confirmation). Action loop until user returns to dashboard or exits.

Always include clickable Jira URLs for every issue key.

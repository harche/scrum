Analyze carryover items from the current sprint.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team's sprint filter for all subsequent steps.

2. Find the active sprint for the selected team:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprints active` — filter for the team's sprint name pattern.

2. Get all sprint issues:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprint-issues <sprintId>`

3. Filter to items NOT in Done/Closed/Verified status — these are carryovers.

4. For each carryover, check if it has a Blocked field or Blocked Reason set.

## Output

### Sprint Summary
- Sprint name, end date, days remaining
- Items completed vs total

### Carryover Items
Table: key, type, summary, status, assignee, story points, blocked reason (if any)

### Interactive Review (Dynamic)
Present carryovers one at a time (or in small groups by assignee). For each carryover:
- Show: key, summary, status, assignee, story points, why it's carrying over (infer from status)
- **Fetch available transitions:** `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh transitions <KEY>`
- **Check current state:**
  - Has story points? → offer "Re-estimate story points" : "Set story points"
  - Is blocked (customfield_10517)? → offer "Unflag blocker" : "Flag as blocked"
  - Has assignee? → offer "Reassign" : "Assign"
  - Is there a future sprint? → offer "Move to next sprint" with the future sprint name

- Use `AskUserQuestion`: "What to do with [KEY]?" with dynamic options:
  - "Move to next sprint (keep)" — if future sprint exists
  - "Descope / remove from sprint"
  - List each available transition by name (from the transitions API, e.g., "Close", "Move to In Progress")
  - Include the state-based options above (re-estimate, reassign, blocker toggle)
  - "Add a comment"
  - "Skip"

- **Execute the chosen action** (with confirmation). After executing, re-fetch state and offer follow-up actions before moving to the next carryover.

### Summary Stats (shown at the end)
- Total carryover count and story points
- By assignee: who has the most carryovers
- By type: bugs vs stories vs spikes

Always include clickable Jira URLs.

Analyze carryover items from the current Node Devices sprint.

## Steps

1. Find the active Node Core sprint:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprints active` — filter for "Node Core" in name.

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

### Interactive Review
Present carryovers one at a time (or in small groups by assignee). For each carryover:
- Show: key, summary, status, assignee, story points, why it's carrying over (infer from status)
- Use `AskUserQuestion` to ask: "What to do with this carryover?" with options:
  - Move to next sprint (keep)
  - Descope / remove from sprint
  - Re-estimate story points
  - Reassign
  - Skip

### Summary Stats (shown at the end)
- Total carryover count and story points
- By assignee: who has the most carryovers
- By type: bugs vs stories vs spikes

Always include clickable Jira URLs.

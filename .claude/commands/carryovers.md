Analyze carryover items from the current sprint.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team name for the composite command.

2. **Fetch all carryover data in one call:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh carryover-report "<team>"`

   This returns: `activeSprint`, `futureSprint` (or null), `carryovers` (not-done items with `previousSprints` count and `blocked` flag), `doneItems`, `stats` (totalItems, doneCount, carryoverCount, carryoverPoints, donePoints, byAssignee).

## Output

### Sprint Summary
From `activeSprint` and `stats`: Sprint name, end date, days remaining, items completed vs total.

### Carryover Items
Table from `carryovers`: key, type, summary, status, assignee, story points, blocked (if true), previousSprints count.

### Interactive Review (Dynamic)
Present carryovers one at a time (or in small groups by assignee). For each carryover:
- Show: key, summary, status, assignee, story points, why it's carrying over (infer from status)
- **Fetch available transitions:** `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh transitions <KEY>`
- **Check current state:**
  - Has story points? → offer "Re-estimate story points" : "Set story points"
  - Is blocked (customfield_10517)? → offer "Unflag blocker" : "Flag as blocked"
  - Has assignee? → offer "Reassign" : "Assign"
  - Is there a future sprint (`futureSprint` not null)? → offer "Move to next sprint" with the future sprint name

- Use `AskUserQuestion`: "What to do with [KEY]?" with dynamic options:
  - "Move to next sprint (keep)" — if future sprint exists
  - "Descope / remove from sprint"
  - List each available transition by name (from the transitions API, e.g., "Close", "Move to In Progress")
  - Include the state-based options above (re-estimate, reassign, blocker toggle)
  - "Add a comment"
  - "Skip"

- **Execute the chosen action** (with confirmation). After executing, re-fetch state and offer follow-up actions before moving to the next carryover.

### Summary Stats (shown at the end)
From `stats`: Total carryover count and story points, by assignee (from `byAssignee`), by type.

Always include clickable Jira URLs.

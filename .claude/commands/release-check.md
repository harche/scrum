Check release readiness for Node components.

Takes an optional argument: OCP version (e.g., 4.22). If not provided, the composite command discovers the most common active fixVersion automatically.

Argument: $ARGUMENTS (optional OCP version, e.g., "4.22")

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team name for the composite command.

2. **Fetch all release data in one call:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh release-data "<team>" $ARGUMENTS`

   This returns: `version`, `summary` (approvedBlockers, proposedBlockers, openBugs, epics counts), and arrays: `approvedBlockers`, `proposedBlockers`, `openBugs`, `epics`.

## Output

### Release Readiness — OCP [version]

### Blockers
- Approved blockers table from `approvedBlockers` (CRITICAL — must fix)
- Proposed blockers table from `proposedBlockers` (needs triage decision)

### Open Bugs
Table from `openBugs`: key, summary, priority, status, assignee

### Epic Status
Table from `epics`: key, summary, status, assignee

### Assessment
- Ship/no-ship recommendation based on blocker count and severity
- Key risks

### Contextual Actions (Dynamic)

Present blockers and high-risk items interactively. For each item:

1. **Fetch available transitions:** `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh transitions <KEY>`
2. **Check current state:**
   - Is blocked? → offer "Unflag blocker" : "Flag as blocked"
   - Has assignee? → offer "Reassign" : "Assign" (list roster members)
   - Is release blocker approved/proposed? → offer "Change release blocker status"
   - Has SFDC cases? → offer "View customer cases"

3. **Build dynamic options** for `AskUserQuestion`: "What to do with [KEY]?"
   - List each available transition by name (from the transitions API)
   - "Escalate (add comment + change priority)"
   - Include the state-based options
   - "Add a comment"
   - "Investigate (deep dive)"
   - "Mark as accepted risk" (add comment noting acceptance)
   - "Skip"

4. **Execute the chosen action** (with confirmation). Action loop until user skips.

After all blockers reviewed, offer final actions:
- "Act on an open bug from the list" — then select and offer per-item dynamic actions
- "Run `/bug-triage`" — full triage session
- "Done"

Always include clickable Jira URLs.

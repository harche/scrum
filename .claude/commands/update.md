Quick status update on a Jira issue — add a comment, change status, or update story points.

Arguments: $ARGUMENTS
Format: `<ISSUE-KEY>`
Example: `/update OCPNODE-1234` or `/update OCPBUGS-65805`

## Steps

1. **Fetch issue data:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh issue-deep-dive $ARGUMENTS`

   Returns: `key`, `summary`, `status`, `assignee`, `points`, `blocked`, `blockedReason`, `transitions[]` (available transitions with id and name).

2. Show brief issue context: key, summary, status, assignee, points.

3. **Build dynamic options** from the returned data:
   - List each transition by name from `transitions[]`
   - Has points? → "Update story points" : "Set story points"
   - Is blocked? → "Unflag blocker" : "Flag as blocked"
   - "Add a comment"
   - "Reassign"
   - "Done"

4. Use `AskUserQuestion`: "What would you like to do with [$ARGUMENTS]?"

5. **Execute the chosen action** (with confirmation).

6. **Action loop:** After executing, re-fetch via `bin/jira.sh issue-deep-dive $ARGUMENTS`, offer next actions. Continue until "Done".

Always include clickable Jira URL.

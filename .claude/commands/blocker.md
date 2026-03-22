Flag or unflag a blocker on a Jira issue.

Arguments: $ARGUMENTS
Format: `<ISSUE-KEY>`
Example: `/blocker OCPNODE-1234` or `/blocker OCPBUGS-65805`

## Steps

1. **Fetch issue data:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh issue-deep-dive $ARGUMENTS`

   Returns: `key`, `summary`, `status`, `assignee`, `blocked` (boolean), `blockedReason` (plain text), `transitions[]`.

2. Check the `blocked` field to determine current state.

3. **If currently blocked (`blocked: true`):**
   - Show: "[$ARGUMENTS] is currently BLOCKED. Reason: `blockedReason`"
   - Use `AskUserQuestion`: "Unflag blocker on [$ARGUMENTS]?"
   - If confirmed, unflag the blocker.

4. **If not blocked (`blocked: false`):**
   - Use `AskUserQuestion`: "What is blocking [$ARGUMENTS]?" (free text)
   - Draft the blocker: flag + reason
   - Confirm, then set blocked flag + reason

5. After toggling, offer follow-up actions from `transitions[]`:
   - List available transitions by name
   - "Add a comment"
   - "Done"

Always include clickable Jira URL.

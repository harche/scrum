Flag or unflag a blocker on a Jira issue.

Arguments: $ARGUMENTS
Format: `<ISSUE-KEY>`
Example: `/blocker OCPNODE-1234` or `/blocker OCPBUGS-65805`

## Steps

1. **Fetch the issue:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh get $ARGUMENTS`

2. **Check current blocked state:**
   Check the Blocked field (customfield_10517) and Blocked Reason (customfield_10483).

3. **Show current state:**
   Display: key, summary, status, assignee.
   - If currently blocked: show "BLOCKED: [reason]"
   - If not blocked: show "Not currently blocked"

4. **Ask for action:**
   Use `AskUserQuestion`:
   - If currently blocked: "What would you like to do?" with options:
     - Remove the blocker flag
     - Update the blocked reason
     - Investigate the blocker
   - If not blocked: "What would you like to do?" with options:
     - Flag as blocked
     - No action needed

5. **Execute:**

   **Flag as blocked:**
   - Use `AskUserQuestion`: "What's blocking this issue?"
   - Draft a comment summarizing the blocker
   - Use `AskUserQuestion` to confirm: "Flag [KEY] as blocked with this reason and add a comment?"
   - If confirmed:
     - Set Blocked field via REST API:
       ```
       curl -s -X PUT "https://redhat.atlassian.net/rest/api/3/issue/$ARGUMENTS" \
         -H "Authorization: Basic $(echo -n "$JIRA_EMAIL:$JIRA_API_TOKEN" | base64)" \
         -H "Content-Type: application/json" \
         -d '{"fields": {"customfield_10517": {"value": "True"}, "customfield_10483": "<reason>"}}'
       ```
     - Post the blocker comment

   **Remove the blocker flag:**
   - Use `AskUserQuestion` to confirm: "Remove blocker flag from [KEY]?"
   - If confirmed, clear the Blocked field and Blocked Reason

   **Update the blocked reason:**
   - Use `AskUserQuestion`: "What's the updated blocked reason?"
   - Update the Blocked Reason field

6. **Contextual follow-up actions (Dynamic):**

   After executing the blocker action, resolve further actions from the API:
   a. Fetch available transitions: `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh transitions $ARGUMENTS`
   b. Re-check the issue state (re-fetch: `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh get $ARGUMENTS`)
   c. Build dynamic options for `AskUserQuestion`: "Any follow-up actions on [$ARGUMENTS]?"
      - List each available transition by name (from the transitions API)
      - Has story points? → "Update story points" : "Set story points"
      - Is now blocked? → "Update blocked reason" / "Unflag blocker"
      - Is now unblocked? → "Flag as blocked" (if they changed their mind)
      - Always include: "Add a comment"
      - Always include: "Done (no action needed)"
   d. Execute chosen action (with confirmation). Loop until user picks "Done".

Always include clickable Jira URLs.

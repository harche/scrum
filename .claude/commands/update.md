Quick status update on a Jira issue — add a comment, change status, or update story points.

Arguments: $ARGUMENTS
Format: `<ISSUE-KEY>`
Example: `/update OCPNODE-1234` or `/update OCPBUGS-65805`

## Steps

1. **Fetch the issue:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh get $ARGUMENTS`

2. **Show current state:**
   Display: key, summary, status, assignee, story points, sprint, priority.
   Convert description from ADF to readable text (brief summary, first ~3 lines).

3. **Ask what to update:**
   Use `AskUserQuestion`: "What would you like to update on [KEY]?" with options:
   - Add a comment
   - Transition status
   - Set story points
   - Reassign

4. **Execute the chosen action:**

   **Add a comment:**
   - Use `AskUserQuestion` to ask: "What should the comment say?"
   - Draft the comment and show it to the user
   - Use `AskUserQuestion` to confirm: "Post this comment to [KEY]?"
   - If confirmed, post via Jira REST API:
     ```
     curl -s -X POST "https://redhat.atlassian.net/rest/api/3/issue/$ARGUMENTS/comment" \
       -H "Authorization: Basic $(echo -n "$JIRA_EMAIL:$JIRA_API_TOKEN" | base64)" \
       -H "Content-Type: application/json" \
       -d '{"body": {"type": "doc", "version": 1, "content": [{"type": "paragraph", "content": [{"type": "text", "text": "<comment>"}]}]}}'
     ```

   **Transition status:**
   - Get available transitions: `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh transitions $ARGUMENTS`
   - Use `AskUserQuestion` to show available transitions as options
   - Use `AskUserQuestion` to confirm: "Move [KEY] to [new status]?"
   - If confirmed, execute the transition via REST API

   **Set story points:**
   - Use `AskUserQuestion`: "How many story points?" with options: 1, 2, 3, 5, 8
   - Use `AskUserQuestion` to confirm: "Set [KEY] to [N] points?"
   - If confirmed: `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh set-points $ARGUMENTS <points>`

   **Reassign:**
   - Use `AskUserQuestion`: "Who should this be assigned to?" — search both roster files for names as options
   - Use `AskUserQuestion` to confirm the reassignment
   - If confirmed, update via REST API

Always include clickable Jira URLs.

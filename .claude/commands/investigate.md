Deep-dive investigation on a Jira issue. Provide the issue key as an argument: /investigate OCPNODE-1234

Argument: $ARGUMENTS (the issue key, e.g., OCPNODE-4161 or OCPBUGS-65805)

## Steps

1. **Fetch all issue data in one call:**
   `bin/jira.sh issue-deep-dive $ARGUMENTS`

   This returns: `key`, `summary`, `description` (plain text, already converted from ADF), `status`, `statusCategory`, `assignee`, `assigneeEmail`, `priority`, `type`, `points`, `fixVersions`, `epicKey`, `releaseBlocker`, `blocked`, `blockedReason`, `sfdcCaseCount`, `sfdcLinks`, `linkedIssues[]`, `comments[]` (each with author, created, body as plain text), `transitions[]` (available transitions with id and name).

2. If the issue has an Epic Link (`epicKey`), fetch the epic for broader context:
   `bin/jira.sh get <epicKey>`

## Output

### Issue Overview
- Key, summary, type, status, priority, assignee
- Created date, updated date
- Sprint, story points, fix version
- Epic (if linked)
- Clickable URL

### Description
Full description from `description` field (already plain text).

### Comments
Show comments from `comments[]` in chronological order with author and date. Summarize if there are more than 5.

### Linked Issues
Table from `linkedIssues[]`: relationship, key, summary, status.

### Support Cases
List any linked SFDC cases from `sfdcCaseCount` / `sfdcLinks`.

### Timeline
Key status changes and dates (inferred from comments/description).

### Summary
Brief assessment: what's the current state, what's blocking progress, what needs to happen next.

### Contextual Actions (Dynamic)

After presenting the investigation, use transitions from the already-fetched `transitions[]` array:

1. **Check current state** from the already-fetched issue data:
   - Has story points (`points`)? → offer "Update story points" : "Set story points"
   - Is blocked (`blocked`)? → offer "Unflag blocker" : "Flag as blocked"
   - Has assignee? → offer "Reassign" : "Assign"
   - Has linked SFDC cases? → offer "View customer cases"

2. **Build dynamic options** for `AskUserQuestion`: "What would you like to do with [$ARGUMENTS]?"
   - List each available transition by name from `transitions[]` (e.g., "Move to In Progress", "Move to Code Review", "Close")
   - Include the state-based options from step 1
   - Always include: "Add a comment"
   - Always include: "Done (no action needed)"

3. **Execute the chosen action** (with confirmation via `AskUserQuestion` for any write operation).

4. **Action loop:** After executing an action, re-fetch the issue via `bin/jira.sh issue-deep-dive $ARGUMENTS` and offer the next set of contextual actions. Continue until the user picks "Done".

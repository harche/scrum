Prepare a handoff summary for a Jira issue being transferred to another team member.

Arguments: $ARGUMENTS
Format: `<ISSUE-KEY>`
Example: `/handoff OCPNODE-1234` or `/handoff OCPBUGS-65805`

## Steps

Run these in parallel:

1. **Fetch the issue:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh get $ARGUMENTS`

2. **Fetch comments:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh comments $ARGUMENTS`

3. **Search for related GitHub PRs:**
   ```
   gh search prs "$ARGUMENTS" --sort=updated --limit=10 --json repository,title,state,url,author,createdAt,updatedAt,mergedAt
   ```

## Output

### Handoff Summary — [KEY]: [Summary]

### Current State
- Status: [status]
- Assignee: [current assignee]
- Sprint: [sprint name]
- Story Points: [pts]
- Priority: [priority]

### What This Issue Is About
Description converted from ADF to readable text, condensed to key points.

### What's Been Done
Summarize from comments and PR activity:
- Key decisions made (from comments)
- PRs opened/merged (from GitHub search)
- Current progress state

### What's Remaining
Based on the description, comments, and current status:
- Remaining work items
- Known open questions
- Dependencies on other issues (from issuelinks)

### Key Context
- Important comments or discussions (summarize, don't dump raw text)
- Related issues and their status
- Any customer impact (SFDC cases)
- Blockers or risks

### Related PRs
| # | Repo | Title | State | Author | URL |
|---|------|-------|-------|--------|-----|

### Suggested Next Steps
1. [Concrete next action]
2. [Follow-up action]
3. [etc.]

Always include clickable Jira and GitHub URLs.

### Contextual Actions (Dynamic)

After presenting the handoff summary, resolve available actions from the API:

1. **Fetch available transitions:** `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh transitions $ARGUMENTS`
2. **Check current state** from the already-fetched issue data:
   - Has story points (customfield_10028)? → offer "Update story points" : "Set story points"
   - Is blocked (customfield_10517 set)? → offer "Unflag blocker" : "Flag as blocked"

3. **Build dynamic options** for `AskUserQuestion`: "What would you like to do with [$ARGUMENTS]?"
   - "Reassign to a team member" — always offered (this is a handoff)
   - "Post handoff summary as a comment"
   - List each available transition by name (e.g., "Move to To Do", "Move to In Progress") — from the transitions API
   - Include the state-based options from step 2
   - Always include: "Done (no action needed)"

4. **Execute the chosen action** (with confirmation via `AskUserQuestion` for any write operation):

   **Reassign flow:**
   - Search both `config/team-roster-dra.json` and `config/team-roster-core.json` for team member names
   - Use `AskUserQuestion` to pick the new assignee from roster names
   - Use `AskUserQuestion` to confirm: "Reassign [KEY] to [name] and post handoff comment?"
   - If confirmed: reassign via REST API and post the handoff summary as a Jira comment

   **Post comment flow:**
   - Draft the handoff summary as a Jira comment
   - Use `AskUserQuestion` to confirm
   - If confirmed, post via REST API

5. **Action loop:** After executing an action, re-fetch the issue and transitions, then offer the next set of contextual actions. Continue until the user picks "Done".

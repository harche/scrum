Prepare a handoff summary for a Jira issue being transferred to another team member.

Arguments: $ARGUMENTS
Format: `<ISSUE-KEY>`
Example: `/handoff OCPNODE-1234` or `/handoff OCPBUGS-65805`

## Steps

Run these in parallel:

1. **Fetch issue data (Jira):**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh issue-deep-dive $ARGUMENTS`

   Returns: `key`, `summary`, `description` (plain text), `status`, `assignee`, `priority`, `type`, `points`, `fixVersions`, `epicKey`, `blocked`, `blockedReason`, `sfdcCaseCount`, `linkedIssues[]`, `comments[]` (plain text), `transitions[]`.

2. **Search for related GitHub PRs:**
   ```
   gh search prs "$ARGUMENTS" --sort=updated --limit=10 --json repository,title,state,url,author,createdAt,updatedAt,mergedAt
   ```

## Output

### Handoff Summary — [KEY]: [Summary]

### Current State
- Status, assignee, sprint, story points, priority (from issue data)

### What This Issue Is About
Description from `description` field, condensed to key points.

### What's Been Done
Summarize from `comments[]` and PR activity:
- Key decisions made (from comments)
- PRs opened/merged (from GitHub search)
- Current progress state

### What's Remaining
Based on description, comments, and status:
- Remaining work items
- Known open questions
- Dependencies from `linkedIssues[]`

### Key Context
- Important comments (summarize from `comments[]`, don't dump raw text)
- Related issues from `linkedIssues[]` and their status
- Any customer impact (`sfdcCaseCount`)
- Blockers or risks (`blocked`, `blockedReason`)

### Related PRs
| # | Repo | Title | State | Author | URL |
|---|------|-------|-------|--------|-----|

### Suggested Next Steps
1. [Concrete next action]
2. [Follow-up action]
3. [etc.]

Always include clickable Jira and GitHub URLs.

### Contextual Actions (Dynamic)

After presenting the handoff summary, use transitions from the already-fetched `transitions[]`:

1. **Check current state:**
   - Has story points? → offer "Update story points" : "Set story points"
   - Is blocked? → offer "Unflag blocker" : "Flag as blocked"

2. **Build dynamic options** for `AskUserQuestion`: "What would you like to do with [$ARGUMENTS]?"
   - "Reassign to a team member" — always offered (this is a handoff)
   - "Post handoff summary as a comment"
   - List each available transition by name from `transitions[]`
   - Include the state-based options
   - "Done (no action needed)"

3. **Execute the chosen action** (with confirmation):

   **Reassign flow:**
   - Search both `config/team-roster-dra.json` and `config/team-roster-core.json` for team member names
   - Use `AskUserQuestion` to pick the new assignee from roster names
   - Use `AskUserQuestion` to confirm: "Reassign [KEY] to [name] and post handoff comment?"
   - If confirmed: reassign via REST API and post the handoff summary as a Jira comment

   **Post comment flow:**
   - Draft the handoff summary as a Jira comment
   - Use `AskUserQuestion` to confirm
   - If confirmed, post via REST API

4. **Action loop:** After executing, re-fetch via `bin/jira.sh issue-deep-dive $ARGUMENTS`, offer next actions. Continue until "Done".

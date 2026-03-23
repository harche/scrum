Get up to speed on a Jira issue — full details, recent activity, linked PRs, and related issues.

Arguments: $ARGUMENTS
Format: `<ISSUE-KEY>`
Example: `/briefing OCPNODE-1234` or `/briefing OCPBUGS-65805`

## Steps

Run these in parallel:

1. **Fetch issue data (Jira):**
   `bin/jira.sh issue-deep-dive $ARGUMENTS`

   Returns: `key`, `summary`, `description` (plain text), `status`, `assignee`, `priority`, `type`, `points`, `fixVersions`, `epicKey`, `releaseBlocker`, `blocked`, `blockedReason`, `sfdcCaseCount`, `linkedIssues[]`, `comments[]` (plain text), `transitions[]`.

2. **Search for related GitHub PRs:**
   ```
   gh search prs "$ARGUMENTS" --sort=updated --limit=10 --json repository,title,state,url,author,createdAt,updatedAt,mergedAt
   ```

## Output

### Context — [KEY]: [Summary]

### Issue Details
| Field | Value |
|-------|-------|
| Type | [type] |
| Status | [status] |
| Priority | [priority] |
| Assignee | [name] |
| Sprint | [sprint name] |
| Story Points | [pts] |
| Epic | [epic key — epic summary] |
| Fix Version | [version] |
| Release Blocker | [flag if set] |
| Customer Cases | [count if any] |

### Description
Full description from `description` field (already plain text).

### Comments (Recent)
Show the last 5 comments from `comments[]` in chronological order:
- **[Author]** ([date]): [comment text]

If more than 5 comments, show count and summarize older ones.

### Linked Issues
From `linkedIssues[]`:
| # | Relationship | Key | Summary | Status |
|---|-------------|-----|---------|--------|

### Related GitHub PRs
PRs that reference this issue key in their title or body:
| # | Repo | Title | Author | State | URL |
|---|------|-------|--------|-------|-----|

### Timeline
Reconstruct a brief timeline from comments and status:
- [date]: Created
- [date]: Key comment/status change
- [date]: PR opened / merged

### Quick Assessment
- Current state in 1-2 sentences
- What needs to happen next
- Any blockers or dependencies
- Estimated effort (based on story points and remaining work)

Always include clickable Jira and GitHub URLs.

### Contextual Actions (Dynamic)

After presenting context, use transitions from the already-fetched `transitions[]`:

1. **Check current state** from the issue data:
   - Has story points? → offer "Update story points" : "Set story points"
   - Is blocked? → offer "Unflag blocker" : "Flag as blocked"
   - Has assignee? → offer "Reassign" : "Assign"
   - Has related GitHub PRs? → offer "View PR #N" for each PR found

2. **Build dynamic options** for `AskUserQuestion`: "What would you like to do with [$ARGUMENTS]?"
   - List each available transition by name from `transitions[]`
   - Include the state-based options
   - Always include: "Add a comment", "Done (no action needed)"

3. **Execute the chosen action** (with confirmation).

4. **Action loop:** After executing, re-fetch via `bin/jira.sh issue-deep-dive $ARGUMENTS`, offer next actions. Continue until "Done".

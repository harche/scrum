Get up to speed on a Jira issue — full details, recent activity, linked PRs, and related issues.

Arguments: $ARGUMENTS
Format: `<ISSUE-KEY>`
Example: `/context OCPNODE-1234` or `/context OCPBUGS-65805`

## Steps

Run these in parallel where possible:

1. **Fetch the issue:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh get $ARGUMENTS`

2. **Fetch comments:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh comments $ARGUMENTS`

3. **Search for related GitHub PRs:**
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
| Reporter | [name] |
| Sprint | [sprint name] |
| Story Points | [pts] |
| Epic | [epic key — epic summary] |
| Fix Version | [version] |
| Created | [date] |
| Updated | [date] |
| Release Blocker | [flag if set] |
| Customer Cases | [count if any] |

### Description
Full description converted from ADF to readable text.

### Comments (Recent)
Show the last 5 comments in chronological order:
- **[Author]** ([date]): [comment text converted from ADF]

If more than 5 comments, show count and summarize older ones.

### Linked Issues
From the issue's `issuelinks` field:
| # | Relationship | Key | Summary | Status |
|---|-------------|-----|---------|--------|

### Related GitHub PRs
PRs that reference this issue key in their title or body:
| # | Repo | Title | Author | State | URL |
|---|------|-------|--------|-------|-----|

### Timeline
Reconstruct a brief timeline from comments and status:
- [date]: Created by [reporter]
- [date]: Assigned to [assignee]
- [date]: Key comment/status change
- [date]: PR opened / merged

### Quick Assessment
- Current state in 1-2 sentences
- What needs to happen next
- Any blockers or dependencies
- Estimated effort (based on story points and remaining work)

Always include clickable Jira and GitHub URLs.

### Actions
After presenting context, use `AskUserQuestion` to ask: "What would you like to do?" with options:
- Update this issue (comment, transition, points)
- Flag/unflag as blocked
- Open a linked PR
- No actions needed

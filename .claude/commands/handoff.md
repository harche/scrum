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

### Actions
After presenting the handoff summary, use `AskUserQuestion` to ask: "What would you like to do?" with options:
- Reassign to a team member (show roster names)
- Post handoff summary as a comment on the issue
- No actions needed

**Reassign flow:**
- Search both `config/team-roster-dra.json` and `config/team-roster-core.json` for team member names
- Use `AskUserQuestion` to pick the new assignee
- Use `AskUserQuestion` to confirm: "Reassign [KEY] to [name] and post handoff comment?"
- If confirmed: reassign via REST API and post the handoff summary as a Jira comment

**Post comment flow:**
- Draft the handoff summary as a Jira comment
- Use `AskUserQuestion` to confirm
- If confirmed, post via REST API

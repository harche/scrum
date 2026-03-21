Generate my personal standup talking points — what I did, what I'm doing, and what's blocking me.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team's sprint filter.

2. **Find the active sprint:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprints active` — filter for the selected team's sprint name pattern. Note sprint ID, startDate, endDate.

3. Run these queries **in parallel:**

   a. **My sprint items:**
      `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprint-issues <sprintId>`
      Filter to items assigned to `harpatil@redhat.com`.

   b. **My recent Jira activity:**
      `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'assignee = "harpatil@redhat.com" AND updated >= -7d ORDER BY updated DESC'`

   c. **My GitHub PRs (last 7 days):**
      ```
      gh search prs --author=harche --updated=">=7-days-ago" --sort=updated --limit=20 --json repository,title,state,url,updatedAt,createdAt
      ```

   d. **My GitHub reviews (last 7 days):**
      ```
      gh search prs --reviewed-by=harche --updated=">=7-days-ago" --sort=updated --limit=10 --json repository,title,url,author,state
      ```

4. **For each of my sprint items, fetch recent comments:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh comments <ISSUE-KEY>`
   Filter to last 7 days. Extract readable text from ADF body.

## Output

### My Standup — [Date]
Sprint: [name] | Day X of Y

### Done (since last standup)
- Jira items moved to Done/Closed/Verified in the last 7 days
- PRs merged in the last 7 days
- PR reviews completed

### In Progress
- Jira items currently In Progress or Code Review
- Open PRs (with review status)

### Blocked
- Any of my items with Blocked field set (show blocked reason)
- PRs with failing CI or changes requested

### Up Next
- Items still in To Do assigned to me
- Review requests pending

### Talking Points
Auto-generated 3-5 bullet points suitable for reading aloud at standup:
- "I completed [X] and [Y]"
- "I'm currently working on [Z], which is [status]"
- "I'm blocked on [W] because [reason]"
- "Next I'll pick up [V]"

Always include clickable Jira and GitHub URLs.

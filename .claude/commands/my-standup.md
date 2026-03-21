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

### Contextual Actions (Dynamic)

After presenting the standup, use `AskUserQuestion`: "What would you like to do?" with dynamic options based on the data:

**For Jira items:**
- If any blocked items exist → "Unblock [KEY]: [summary]" for each blocked item
- If any items in To Do → "Start working on [KEY]" (transition to In Progress)
- If any items in Progress → "Move [KEY] to Code Review" (if transition available)

**For GitHub PRs:**
- If any PRs approved + checks passing → "Merge [PR title]"
- If any PRs with failing CI → "Check CI on [PR title]"
- If any PRs with no reviews → "Request review on [PR title]"

**Always include:**
- "Act on a Jira item" — then ask which item number, fetch transitions + state, offer dynamic actions
- "Act on a GitHub PR" — then ask which PR, fetch PR state via `gh pr view`, offer dynamic actions
- "Done (no actions needed)"

**When user picks a Jira item:**
1. Fetch transitions: `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh transitions <KEY>`
2. Check state: has points? blocked? assignee?
3. Build dynamic options: transitions, set points, flag/unflag blocker, add comment, investigate
4. Execute with confirmation. Action loop until user returns.

**When user picks a GitHub PR:**
1. Fetch PR state: `gh pr view <PR-URL> --json state,reviewDecision,statusCheckRollup,isDraft,mergeable`
2. Build dynamic options based on state (merge, request review, view checks, comment, close)
3. Execute with confirmation. Action loop until user returns.

Always include clickable Jira and GitHub URLs.

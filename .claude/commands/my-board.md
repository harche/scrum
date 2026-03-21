Show my personal sprint board — all issues assigned to me in the current sprint.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team's sprint filter for all subsequent steps.

2. **Find the active sprint:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprints active` — filter for the selected team's sprint name pattern. Note its ID, name, startDate, endDate.

3. **Get sprint issues:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprint-issues <sprintId>`

4. **Filter to my issues:**
   Filter the sprint issues to only those where the assignee's emailAddress matches `harpatil@redhat.com` (the logged-in user).

5. **Display the output** (see Output below).

## Output

### My Board — [Sprint Name]
Days remaining: X of Y | Points: done/total

### Summary
- Total items assigned to me
- Done/Closed count
- In Progress count
- To Do/New count
- Total story points assigned vs completed

### My Items by Status

Group into tables by status category. Each table has: #, Key (clickable), Type, Summary, Story Points.

**Done/Closed:**
| # | Key | Type | Summary | Pts |
|---|-----|------|---------|-----|

**In Progress / Code Review:**
| # | Key | Type | Summary | Pts |
|---|-----|------|---------|-----|

**To Do / New:**
| # | Key | Type | Summary | Pts |
|---|-----|------|---------|-----|

### Flags
- Any of my items that are blocked (Blocked field set) — show blocked reason
- Items with no story points (may need grooming)
- Items still in To Do with < 3 days remaining in sprint

Always include clickable Jira URLs for every issue key.

### Actions
After presenting the board, use `AskUserQuestion` to ask: "What would you like to do?" with options:
- Investigate an item (then ask which #)
- Update an item (comment, transition, or set points)
- Flag/unflag a blocker
- No actions needed

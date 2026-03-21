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

### Contextual Actions (Dynamic)

After presenting the board, use `AskUserQuestion` to ask: "Which item would you like to act on?" with each item number as an option, plus "Done (no actions needed)".

When the user picks an item, resolve that item's available actions from the API:

1. **Fetch available transitions:** `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh transitions <SELECTED-KEY>`
2. **Check current state** from the already-fetched sprint data:
   - Has story points (customfield_10028)? → offer "Update story points" : "Set story points"
   - Is blocked (customfield_10517 set)? → offer "Unflag blocker" : "Flag as blocked"
   - Has assignee? → offer "Reassign" : "Assign"

3. **Build dynamic options** for `AskUserQuestion`: "What would you like to do with [KEY]?"
   - List each available transition by name (from the transitions API)
   - Include the state-based options from step 2
   - Always include: "Add a comment", "Investigate (deep dive)", "Done (back to board)"

4. **Execute the chosen action** (with confirmation via `AskUserQuestion` for any write operation).

5. **Action loop:** After executing an action, re-fetch transitions and state, then offer next actions. When the user picks "Done (back to board)", return to the item selection list to act on another item. Continue until the user picks "Done (no actions needed)" at the top level.

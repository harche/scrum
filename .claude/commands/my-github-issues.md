Show my GitHub issues — filed by me, assigned to me, and ones I've commented on recently.

The user's GitHub handle is `harche` (from roster files).

## Steps

Run these queries **in parallel:**

1. **Issues I authored (open):**
   ```
   gh search issues --author=harche --state=open --sort=updated --limit=20 --json repository,title,state,url,createdAt,updatedAt,labels
   ```

2. **Issues assigned to me (open):**
   ```
   gh search issues --assignee=harche --state=open --sort=updated --limit=20 --json repository,title,state,url,createdAt,updatedAt,labels
   ```

3. **Issues I commented on recently (last 14 days):**
   ```
   gh search issues --commenter=harche --updated=">=14-days-ago" --sort=updated --limit=20 --json repository,title,state,url,author,createdAt,updatedAt
   ```

4. **Issues I recently closed (last 14 days):**
   ```
   gh search issues --author=harche --state=closed --updated=">=14-days-ago" --sort=updated --limit=10 --json repository,title,state,url,updatedAt
   ```

## Output

### My GitHub Issues — @harche

### Summary
- Open issues I authored: N
- Open issues assigned to me: N
- Recently commented on: N
- Recently closed: N
- Repos with open issues: list

### Issues I Authored (Open)
| # | Repo | Title | Age (days) | Labels | URL |
|---|------|-------|------------|--------|-----|

Sort by age (oldest first).

### Issues Assigned to Me (Open)
| # | Repo | Title | Age (days) | Labels | URL |
|---|------|-------|------------|--------|-----|

Only show issues not already listed in the "authored" table above.

### Recently Commented On (14 days)
| # | Repo | Title | Author | My Role | Last Updated | URL |
|---|------|-------|--------|---------|-------------|-----|

My Role: author / assignee / commenter
Only show issues not already in the tables above.

### Recently Closed (14 days)
| # | Repo | Title | Closed | URL |
|---|------|-------|--------|-----|

### Flags
- Issues open > 30 days with no recent activity (may be stale)
- Issues with no assignee (authored by me but unassigned)

Always include clickable GitHub URLs.

### Contextual Actions (Dynamic)

After presenting the report, use `AskUserQuestion`: "Which issue would you like to act on?" with each issue number as an option, plus "Done (no actions needed)".

When the user picks an issue, resolve its available actions from the GitHub API:

1. **Fetch issue details:** `gh issue view <ISSUE-URL> --json state,assignees,labels,comments`
2. **Build dynamic options** based on the issue's current state:
   - **If open + I authored it:** "Close as completed", "Close as not planned"
   - **If open + no assignee:** "Assign to me", "Assign to..." (list team members)
   - **If open:** "Add a label" (show existing repo labels), "Remove a label"
   - **If stale (>30 days, flagged above):** "Add a status update comment", "Close as stale"
   - Always include: "Add a comment", "Open in browser", "Done (back to list)"

3. **Execute the chosen action** (with confirmation via `AskUserQuestion` for any write operation).

4. **Action loop:** After executing an action, re-fetch issue state and offer updated actions. Continue until user picks "Done (back to list)". Then return to issue selection.

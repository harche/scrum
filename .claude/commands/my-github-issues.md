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

### Actions
After presenting the report, use `AskUserQuestion` to ask: "What would you like to do?" with options:
- Open an issue in browser
- No actions needed

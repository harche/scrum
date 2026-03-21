Show PRs waiting for my review, prioritized by age and importance.

The user's GitHub handle is `harche` (from roster files).

## Steps

Run these queries **in parallel:**

1. **PRs requesting my review (directly):**
   ```
   gh search prs --review-requested=harche --state=open --sort=updated --limit=30 --json repository,title,url,author,createdAt,updatedAt,labels
   ```

2. **PRs where I'm mentioned but haven't reviewed yet:**
   ```
   gh search prs --mentions=harche --state=open --sort=updated --limit=10 --json repository,title,url,author,createdAt,updatedAt
   ```

## Output

### Review Queue — @harche

### Summary
- Total PRs awaiting my review: N
- Oldest: X days
- By repo: repo1 (N), repo2 (N)

### PRs Needing My Review
| # | Repo | Title | Author | Age (days) | Priority | URL |
|---|------|-------|--------|------------|----------|-----|

Priority is determined by:
- **High**: Age > 5 days, or from a team member (match author against roster files)
- **Medium**: Age 2-5 days
- **Low**: Age < 2 days

Sort by priority (high first), then age (oldest first).

### Mentioned (may need attention)
| # | Repo | Title | Author | Age | URL |
|---|------|-------|--------|-----|-----|

Only show PRs not already in the review-requested list above.

Always include clickable GitHub URLs.

### Actions
After presenting the queue, use `AskUserQuestion` to ask: "What would you like to do?" with options:
- Open a PR in browser
- Skip (done reviewing queue)

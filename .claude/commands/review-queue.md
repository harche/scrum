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

### Contextual Actions (Dynamic)

After presenting the queue, use `AskUserQuestion`: "Which PR would you like to act on?" with each PR number as an option, plus "Done (finished reviewing queue)".

When the user picks a PR, resolve its available actions from the GitHub API:

1. **Fetch PR details:** `gh pr view <PR-URL> --json state,reviewDecision,statusCheckRollup,isDraft,mergeable,additions,deletions,changedFiles`
2. **Build dynamic options** based on the PR's current state:
   - **If checks passing:** "Approve this PR", "Approve and merge"
   - **If checks failing:** "View failing checks", "Comment about failing checks"
   - **If draft:** "Comment (PR is still draft)"
   - Always include: "Add a review comment", "Request changes", "View diff summary" (`gh pr diff <PR-URL> --stat`), "Open in browser", "Done (back to queue)"

3. **Execute the chosen action** (with confirmation via `AskUserQuestion` for any write operation).

4. **Action loop:** After executing an action, re-fetch PR state and offer updated actions. Continue until user picks "Done (back to queue)". Then return to PR selection.

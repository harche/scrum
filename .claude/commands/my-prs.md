Show my open PRs across GitHub — review status, CI status, merge readiness, plus PRs where I'm a requested reviewer.

The user's GitHub handle is `harche` (from roster files).

## Steps

Run these queries **in parallel:**

1. **My authored PRs (open):**
   ```
   gh search prs --author=harche --state=open --sort=updated --limit=30 --json repository,title,state,url,updatedAt,createdAt,reviewDecision,statusCheckRollup
   ```

2. **My recently merged PRs (last 14 days):**
   ```
   gh search prs --author=harche --merged --sort=updated --limit=10 --json repository,title,url,updatedAt
   ```

3. **PRs requesting my review:**
   ```
   gh search prs --review-requested=harche --state=open --sort=updated --limit=20 --json repository,title,url,author,createdAt,updatedAt
   ```

## Output

### My PRs — @harche

### Summary
- Open PRs: N
- Awaiting review: N (no approvals yet)
- Approved & ready to merge: N
- Changes requested: N
- Recently merged (14d): N
- Review requests pending from me: N

### Open PRs (Authored)
| # | Repo | Title | Review Status | CI | Age | URL |
|---|------|-------|--------------|-----|-----|-----|

Review Status: APPROVED / CHANGES_REQUESTED / REVIEW_REQUIRED / PENDING
CI: passing / failing / pending (from statusCheckRollup)

Flag PRs that are:
- Approved but not merged (ready to go!)
- Open > 7 days with no review (may need a ping)
- CI failing (needs attention)

### Recently Merged (14 days)
| # | Repo | Title | Merged | URL |
|---|------|-------|--------|-----|

### Review Requests (PRs needing my review)
| # | Repo | Title | Author | Age | URL |
|---|------|-------|--------|-----|-----|

Sort by age (oldest first — review these first).

Always include clickable GitHub URLs.

### Contextual Actions (Dynamic)

After presenting the report, use `AskUserQuestion`: "Which PR would you like to act on?" with each PR number as an option, plus "Done (no actions needed)".

When the user picks a PR, resolve its available actions from the GitHub API:

1. **Fetch PR details:** `gh pr view <PR-URL> --json state,reviewDecision,statusCheckRollup,isDraft,mergeable,headRefName`
2. **Build dynamic options** based on the PR's current state:
   - **If approved + checks passing + mergeable:** "Merge this PR" (primary action), "Squash and merge", "Rebase and merge"
   - **If approved + checks failing:** "View failing checks" (`gh pr checks <PR-URL>`), "Re-run failed checks"
   - **If changes requested:** "View review comments" (`gh pr view <PR-URL> --comments`), "Push a fix and re-request review"
   - **If no reviews yet:** "Request review from..." (list team members from roster files by GitHub handle)
   - **If draft:** "Mark as ready for review" (`gh pr ready <PR-URL>`)
   - **If checks pending:** "View check status" (`gh pr checks <PR-URL>`)
   - Always include: "Add a comment", "Close PR", "Open in browser", "Done (back to list)"

3. **Execute the chosen action** (with confirmation via `AskUserQuestion` for any write operation).

4. **Action loop:** After executing an action, re-fetch PR state and offer updated actions. Continue until user picks "Done (back to list)". Then return to PR selection.

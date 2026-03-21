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

### Actions
After presenting the report, use `AskUserQuestion` to ask: "What would you like to do?" with options:
- Open a PR in browser
- Check CI details on a PR
- No actions needed

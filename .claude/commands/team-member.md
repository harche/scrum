Show a comprehensive Jira activity summary for a team member during the current sprint.

Arguments: $ARGUMENTS
Format: `<name-or-partial>`
Example: `/team-member Sai` or `/team-member Aditi`

Look up the GitHub handle by matching the name argument (case-insensitive partial match) against roster keys. Search both `config/team-roster-dra.json` and `config/team-roster-core.json`. If no match, ask the user.

## Steps

1. **Determine which team** the person belongs to by checking both roster files.

2. **Fetch Jira standup data and GitHub activity in parallel:**

   Run both commands simultaneously:
   - `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh standup-data "<team>"`
   - `bin/gh-activity.sh member-prs <github-handle>` (using the handle from the roster lookup in step 1)

   Jira returns: `sprint`, `byStatus` (all issues grouped), `memberActivity[]` (per member with sprintItems, commentCount7d, statusSummary).

   GitHub returns: `authored[]`, `reviewed[]`, `issues[]`, `summary` (authored, reviewed, issues counts).

3. Render the target member's data directly from:
   - Items from `byStatus` where assignee matches the name
   - Their entry in `memberActivity[]` for comment count and status summary
   - GitHub `authored[]`, `reviewed[]` for PR activity

## Output

### Activity Summary — [Person Name]
Sprint: `sprint.name`

### Sprint Items
Table of items from `byStatus` where assignee matches: #, key, type, summary, status, points.

### Activity (Last 7 Days)
From `memberActivity[]` for this person:
- Sprint items by status (from `statusSummary`)
- Jira comment count (from `commentCount7d`)

From GitHub `summary` and detail arrays:
- PRs authored: count + table of `authored[]` (repo, title, state, URL)
- PRs reviewed: count + table of `reviewed[]` (repo, title, state, URL)

### Overall Assessment
- What they're primarily working on
- Any items that appear stalled
- Threads needing follow-up

Always include clickable Jira URLs.

### Contextual Actions (Dynamic)

Use `AskUserQuestion`: "What to do?" with:
- "Act on one of [Name]'s items" → ask which, fetch transitions, action loop
- "View a specific PR" → fetch PR state, offer actions (merge, review, comment, etc.)
- "Done"

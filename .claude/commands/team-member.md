Show a comprehensive Jira activity summary for a team member during the current sprint.

Arguments: $ARGUMENTS
Format: `<name-or-partial>`
Example: `/team-member Sai` or `/team-member Aditi`

Look up the GitHub handle by matching the name argument (case-insensitive partial match) against roster keys. Search both `config/team-roster-dra.json` and `config/team-roster-core.json`. If no match, ask the user.

## Steps

1. **Determine which team** the person belongs to by checking both roster files.

2. **Fetch standup data:**
   `bin/jira.sh standup-data "<team>"`

   Returns: `sprint`, `byStatus` (all issues grouped), `memberActivity[]` (per member with sprintItems, commentCount7d, statusSummary).

3. Render the target member's data directly from:
   - Items from `byStatus` where assignee matches the name
   - Their entry in `memberActivity[]` for comment count and status summary

## Output

### Activity Summary — [Person Name]
Sprint: `sprint.name`

### Sprint Items
Table of items from `byStatus` where assignee matches: #, key, type, summary, status, points.

### Jira Activity
From `memberActivity[]` for this person:
- Sprint items by status (from `statusSummary`)
- Comment count (from `commentCount7d`)

### Overall Assessment
- What they're primarily working on
- Any items that appear stalled
- Threads needing follow-up

Always include clickable Jira URLs.

### Contextual Actions (Dynamic)

Use `AskUserQuestion`: "What to do?" with:
- "Act on one of [Name]'s items" → ask which, fetch transitions, action loop
- "Run `/team-member-github <name>`"
- "Done"

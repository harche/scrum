Prepare a summary for the weekly standup/grooming meeting.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team's sprint filter, roster file, and bug components for all subsequent steps.

2. Find the active sprint for the selected team:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprints active` — filter for the team's sprint name pattern.
   Note the sprint startDate and endDate for progress calculation.

3. Load the **team roster** from the selected team's roster file.

4. Run these 3 queries **in parallel:**

   a. Get all sprint issues:
      `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprint-issues <sprintId>`

   b. Find recently updated items (last 7 days):
      `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'sprint = <sprintId> AND updated >= -7d ORDER BY updated DESC'`

   c. Check for new bugs filed against the selected team's components in the last 7 days (use bug components from Team Selection table in CLAUDE.md):
      `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPBUGS AND component in (<team bug components>) AND created >= -7d ORDER BY created DESC'`

5. **Display the output** (see Output below).

6. After displaying the sprint board, use `AskUserQuestion` to ask: "Any actions?" with options:
   - Investigate an item (then ask which #)
   - Run `/standup-github` for team GitHub activity
   - Flag an item as blocked
   - Reassign an item
   - Publish to GitHub Discussions
   - No actions needed

## Output

### Sprint Progress
- Sprint name, days elapsed / total days, items done / total, points completed / total

### Sprint Items
Full table of all sprint issues, grouped by status:

| # | Key | Summary | Status | Assignee | Pts |
|---|-----|---------|--------|----------|-----|

Group order: Closed/Done first, then Code Review, then In Progress, then other statuses.

### Blockers & Risks
- Items with Blocked field set
- Bugs with priority Blocker or Critical
- Items at risk of not completing (considering days remaining)

### New Bugs (Last 7 Days)
Any new bugs filed this week against Devices-related components. "None" if empty.

### Discussion Topics
- Items needing grooming (no story points, no assignee)
- Items that may need to be descoped or carried over (still In Progress with sprint ending soon)

### Jira Activity (Last 7 Days)
For each roster member with sprint items, fetch comments:
`JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh comments <ISSUE-KEY>`
Filter to last 7 days. Extract readable text from ADF body.

Show a table of roster members with their sprint item status and Jira comment count:

| # | Member | Sprint Items | Jira Comments |
|---|--------|-------------|---------------|

For each member:
- **Sprint Items:** count by status (e.g., "2 Done, 1 In Progress") or "—" if none
- **Jira Comments:** count of comments in the last 7 days

Always include clickable Jira URLs and GitHub URLs.

## Publishing to GitHub Discussions (Optional)

When the user opts to publish, use `bin/gh-discussion.sh` to build and post the report:

1. **Build the report body** — write to a temp file the full standup report.

2. **Post:** `bin/gh-discussion.sh publish "Standup — YYYY-MM-DD | Sprint N Day X/Y" <body-file>`
   Show the returned discussion URL to the user.

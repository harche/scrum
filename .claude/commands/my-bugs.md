Show all bugs assigned to me, sorted by severity, age, and customer impact.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team's bug components for all queries.

2. **My open bugs:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPBUGS AND component in (<team bug components>) AND assignee = "harpatil@redhat.com" AND status not in (CLOSED, Verified, Done) ORDER BY priority ASC, created ASC'`

3. **Check for customer escalations** among my bugs:
   Look for issues with SFDC Cases Counter (customfield_10978) populated.

4. **Check for release blocker flags:**
   Look for issues with Release Blocker (customfield_10847) set.

## Output

### My Bugs — [Team Name]

### Summary
- Total open bugs assigned to me
- By priority: Blocker / Critical / Major / Normal / Minor / Undefined
- Customer escalations count
- Release blocker proposals count

### Customer Escalations (if any)
| # | Key | Summary | Priority | Status | Severity | Cases |
|---|-----|---------|----------|--------|----------|-------|

### Release Blockers (if any)
| # | Key | Summary | Priority | Status | Blocker Flag |
|---|-----|---------|----------|--------|-------------|

### All My Bugs
| # | Key | Summary | Priority | Status | Age (days) | Target Version |
|---|-----|---------|----------|--------|------------|----------------|

Sort by: priority (Blocker first), then by age (oldest first).

Always include clickable Jira URLs for every issue key.

### Actions
After presenting bugs, use `AskUserQuestion` to ask: "What would you like to do?" with options:
- Investigate a bug (then ask which #)
- Update a bug (comment, transition)
- No actions needed

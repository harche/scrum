Show the current sprint dashboard.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team's sprint filter for all subsequent steps.

2. Run `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprints active` and find the sprint matching the selected team's sprint name pattern. Note its ID, name, startDate, and endDate.

2. Run `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprint-issues <sprintId>` to get all issues.

3. Parse the JSON and produce a dashboard with:

### Sprint Header
- Sprint name, start date, end date, days remaining

### Summary Counts
Table with: Total items, Done/Closed, In Progress, Code Review, To Do/New, Bugs vs Stories

### Items by Status
Group items into tables by status category:
- **Done/Closed** (collapsed count only unless asked)
- **In Progress** — show key, summary, assignee, story points
- **Code Review** — show key, summary, assignee
- **To Do / New** — show key, summary, assignee, priority
- **Blocked** — any item with Blocked field set, show with blocked reason

### At Risk
Flag items that might not finish this sprint:
- Items still in To Do with < 3 days remaining
- Items with no assignee
- Bugs with Undefined priority (untriaged)

### Team Workload
Table: assignee, # items in progress, # items done, # items total

Always include clickable Jira URLs for every issue key.

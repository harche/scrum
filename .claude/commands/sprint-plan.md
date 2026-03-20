Prepare materials for Node Devices sprint planning.

Takes an optional argument: the next sprint number. If not provided, discover the next future sprint.

## Steps

1. Find active and future Node Core sprints:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprints active`
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprints future`
   Filter for "Node Core" in name. The active sprint is the current one; the future sprint is what we're planning.

2. Get current sprint issues (carryovers):
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprint-issues <activeSprintId>`
   Identify items NOT in Done/Closed/Verified — these are potential carryovers.

3. Get items already in the next sprint:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprint-issues <futureSprintId>`

4. Check the backlog for candidates:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPNODE AND sprint is EMPTY AND status not in (Closed, Done) AND (component in ("Node / Device Manager", "Node / Instaslice-operator") OR summary ~ "DRA" OR summary ~ "DAS" OR summary ~ "Instaslice" OR summary ~ "device") ORDER BY priority DESC, created ASC' `

5. Check for open bugs that should be scheduled:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPBUGS AND component in ("Node / Device Manager", "Node / Instaslice-operator") AND sprint is EMPTY AND status not in (CLOSED, Verified, Done) ORDER BY priority DESC'`

6. Produce the planning report:

### Current Sprint Wrap-up
- Sprint name, end date
- Completion stats: done vs total
- **Carryover candidates**: table of not-done items with key, summary, status, assignee, story points

### Next Sprint
- Sprint name, start/end dates, duration in days

### Already Scheduled
Table of items already in the next sprint: key, summary, assignee, priority, story points

### Backlog Candidates
Table of unscheduled items that could be pulled in: key, summary, priority, story points

### Open Bugs (unscheduled)
Table of bugs not yet in any sprint: key, summary, priority, assignee

### Team Capacity
Discover team members from current sprint assignees. List each person and their current carryover load.

### Suggested Actions
- Which carryovers to keep vs descope
- High-priority backlog items to pull in
- Bugs that need scheduling

Always include clickable Jira URLs.

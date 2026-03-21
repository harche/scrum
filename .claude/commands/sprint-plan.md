Prepare materials for sprint planning.

Takes an optional argument: the next sprint number. If not provided, discover the next future sprint.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team's sprint filter, roster file, and bug components for all subsequent steps.

2. Find active and future sprints for the selected team:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprints active`
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprints future`
   Filter for the team's sprint name pattern. The active sprint is the current one; the future sprint is what we're planning.

2. Get current sprint issues (carryovers):
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprint-issues <activeSprintId>`
   Identify items NOT in Done/Closed/Verified — these are potential carryovers.

3. Get items already in the next sprint:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprint-issues <futureSprintId>`

4. Check the backlog for candidates (use the selected team's bug components and backlog keywords from Team Selection table in CLAUDE.md):
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPNODE AND sprint is EMPTY AND status not in (Closed, Done) AND (component in (<team bug components>) OR summary ~ "<team keywords>") ORDER BY priority DESC, created ASC' `

5. Check for open bugs that should be scheduled (use the selected team's bug components):
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPBUGS AND component in (<team bug components>) AND sprint is EMPTY AND status not in (CLOSED, Verified, Done) ORDER BY priority DESC'`

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
Load the **team roster** from the selected team's roster file.
List every roster member and their current carryover load (0 if none). This shows the full team's availability, not just those with carryovers.

### Interactive Planning (Dynamic)
Go through each section interactively. For each item, resolve available actions from the API:

1. **Carryovers**: For each not-done item:
   - Fetch transitions: `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh transitions <KEY>`
   - Check state: has points? blocked? assignee?
   - Use `AskUserQuestion` with dynamic options:
     - "Move to next sprint (keep)"
     - "Descope / remove from sprint"
     - List available transitions by name (e.g., "Close", "Move to POST")
     - "Re-estimate story points" / "Set story points"
     - "Reassign" / "Assign"
     - "Flag as blocked" / "Unflag blocker"
     - "Add a comment"
     - "Skip"
   - Execute with confirmation. After action, re-fetch and offer follow-up actions.

2. **Backlog candidates**: For each candidate:
   - Fetch transitions: `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh transitions <KEY>`
   - Check state: has points? has assignee?
   - Use `AskUserQuestion` with dynamic options:
     - "Pull into next sprint" (move-to-sprint)
     - "Pull into sprint + assign" (list roster members)
     - "Set story points" / "Update story points"
     - List available transitions by name
     - "Investigate (deep dive)"
     - "Skip"

3. **Open bugs**: For each unscheduled bug:
   - Fetch transitions: `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh transitions <KEY>`
   - Check state: has assignee? has priority? is release blocker?
   - Use `AskUserQuestion` with dynamic options:
     - "Add to next sprint"
     - "Add to sprint + assign" (list roster members)
     - List available transitions by name (e.g., "Move to ASSIGNED")
     - "Set priority"
     - "Close" (if transition available)
     - "Skip"

### Summary (shown at the end)
- Final count of items planned for next sprint
- Total story points planned vs team capacity

### Next Steps
After showing the summary, use `AskUserQuestion` to offer follow-up actions:
- **Run `/bug-triage`** — Review and schedule remaining open bugs
- **Run `/team-load`** — Check updated workload distribution
- **Run `/investigate <KEY>`** — Deep dive on a specific item from the plan
- **Done** — End the planning session

Always include clickable Jira URLs.

Prepare a summary for the weekly Node Devices standup/grooming meeting (Tuesdays 9 AM ET).

## Steps

1. Find the active Node Core sprint:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprints active` — filter for "Node Core" in name.

2. Get all sprint issues:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprint-issues <sprintId>`

3. Find recently updated items (last 7 days) to see what changed since last standup:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'sprint = <sprintId> AND updated >= -7d ORDER BY updated DESC'`

4. Check for new bugs filed against Node components in the last 7 days:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPBUGS AND component in ("Node / Device Manager", "Node / Instaslice-operator") AND created >= -7d ORDER BY created DESC'`

5. Produce the standup report:

### Sprint Progress
- Sprint name, days elapsed / total days, items done / total

### What Changed This Week
Table of items updated in the last 7 days: key, summary, status, assignee, what changed (status transition if visible)

### In Progress Now
Table: key, summary, assignee — for items currently In Progress or Code Review

### Blockers & Risks
- Items with Blocked field set
- Bugs with priority Blocker or Critical
- Items at risk of not completing

### New Bugs
Any new bugs filed this week against Devices-related components

### Discussion Topics
- Items needing grooming (no story points, no assignee, vague summary)
- Items that may need to be descoped or carried over

### Standup Actions
After presenting the report, use `AskUserQuestion` to ask: "Any items to act on before the meeting?" with options:
- Flag an item as blocked
- Highlight specific items for discussion
- Reassign an item
- No actions needed

Always include clickable Jira URLs.

Show workload distribution across the Node Devices team.

## Steps

1. Find the active Node Core sprint:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprints active` — filter for "Node Core".

2. Get all sprint issues:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprint-issues <sprintId>`

3. Group by assignee and compute:
   - Total items assigned
   - Items by status (To Do, In Progress, Code Review, Done)
   - Total story points assigned
   - Story points completed (Done/Closed items)

## Output

### Team Workload — [Sprint Name]

Table per team member:
| Member | To Do | In Progress | Review | Done | Total | Points (done/total) |

### Observations
- Flag anyone with 0 items in progress (may be blocked or between tasks)
- Flag anyone with significantly more items than average (overloaded)
- Flag unassigned items
- Note items without story point estimates

Always include clickable Jira URLs for in-progress items.

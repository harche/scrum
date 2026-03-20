Show workload distribution across the Node Devices team.

## Steps

1. Find the active Node Core sprint:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprints active` — filter for "Node Core".

2. Get all sprint issues:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprint-issues <sprintId>`

3. Load the **full team roster** from `config/team-roster.json`. Every roster member gets a row — not just sprint assignees. Members with 0 assigned items should still appear (they may be available or OOO).

4. Group by roster member and compute:
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

### Rebalancing
If any imbalances are found (overloaded members, unassigned items, idle members), use `AskUserQuestion` to ask: "Would you like to rebalance workload?" with options:
- Reassign specific items (then ask which item and to whom)
- Review a team member's items in detail
- No changes needed

Always include clickable Jira URLs for in-progress items.

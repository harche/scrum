Show workload distribution across the team.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team's sprint filter and roster file for all subsequent steps.

2. Find the active sprint for the selected team:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprints active` — filter for the team's sprint name pattern.

3. Get all sprint issues:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprint-issues <sprintId>`

4. Load the **team roster** from the selected team's roster file.
   Every roster member gets a row — not just sprint assignees. Members with 0 assigned items should still appear (they may be available or OOO).

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

### Contextual Actions (Dynamic)

After presenting workload, use `AskUserQuestion`: "What would you like to do?" with dynamic options based on the data:

**If unassigned items exist:** include "Assign unassigned items" as an option
**If imbalances found (someone has 2x+ average):** include "Rebalance: move items from [overloaded person]"
**If someone has 0 items:** include "Check on [idle person] — assign work or confirm OOO"
**Always include:**
- "Drill into a team member's items" — then ask which member, show their items, and offer per-item actions
- "Act on a specific item" — then ask which item number
- "Run /team-member <name>" — to see full activity for a specific person
- "Done (no changes needed)"

When the user drills into an item, resolve its available actions:
1. Fetch transitions: `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh transitions <KEY>`
2. Check state: has points? blocked? assignee?
3. Build dynamic options: transitions, reassign, set points, flag blocker, add comment
4. Execute with confirmation. Action loop until user returns.

Always include clickable Jira URLs for in-progress items.

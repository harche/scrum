Show workload distribution across the team.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team name for the composite command.

2. **Fetch all sprint data in one call:**
   `bin/jira.sh sprint-dashboard "<team>"`

   This returns: `sprint`, `summary`, `byStatus`, `teamWorkload` (per-member breakdown: toDo, inProgress, codeReview, done, total, pointsDone, pointsTotal), `roster` (all roster members with hasItems flag).

3. Every roster member gets a row — not just sprint assignees. Members with 0 assigned items should still appear (from `roster` with `hasItems: false`).

## Output

### Team Workload — [Sprint Name]

Table per team member (from `teamWorkload` + `roster`):
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
1. Fetch transitions: `bin/jira.sh transitions <KEY>`
2. Check state: has points? blocked? assignee?
3. Build dynamic options: transitions, reassign, set points, flag blocker, add comment
4. Execute with confirmation. Action loop until user returns.

Always include clickable Jira URLs for in-progress items.

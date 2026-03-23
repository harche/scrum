Prepare materials for sprint planning.

Takes an optional argument: the next sprint number. If not provided, discover the next future sprint.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team name for the composite command.

2. **Fetch all planning data in one call:**
   `bin/jira.sh planning-data "<team>"`

   This returns: `activeSprint`, `futureSprint` (or null), `wrapUp` (done + carryovers with counts and points), `scheduled` (items already in next sprint), `backlogCandidates`, `unscheduledBugs`, `roster`.

3. Produce the planning report from the returned data.

### Current Sprint Wrap-up
From `wrapUp`: Sprint name, end date, completion stats (doneCount/carryoverCount, donePoints/carryoverPoints).
**Carryover candidates**: table from `wrapUp.carryovers` — key, summary, status, assignee, story points.

### Next Sprint
From `futureSprint`: Sprint name, start/end dates, duration in days.

### Already Scheduled
Table from `scheduled`: key, summary, assignee, priority, story points.

### Backlog Candidates
Table from `backlogCandidates`: key, summary, priority, story points.

### Open Bugs (unscheduled)
Table from `unscheduledBugs`: key, summary, priority, assignee.

### Team Capacity
From `roster`: List every roster member and their current carryover load (count from `wrapUp.carryovers` filtered by assignee, 0 if none).

### Interactive Planning (Dynamic)
Go through each section interactively. For each item, resolve available actions from the API:

1. **Carryovers**: For each not-done item:
   - Fetch transitions: `bin/jira.sh transitions <KEY>`
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
   - Fetch transitions: `bin/jira.sh transitions <KEY>`
   - Check state: has points? has assignee?
   - Use `AskUserQuestion` with dynamic options:
     - "Pull into next sprint" (move-to-sprint)
     - "Pull into sprint + assign" (list roster members)
     - "Set story points" / "Update story points"
     - List available transitions by name
     - "Investigate (deep dive)"
     - "Skip"

3. **Open bugs**: For each unscheduled bug:
   - Fetch transitions: `bin/jira.sh transitions <KEY>`
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

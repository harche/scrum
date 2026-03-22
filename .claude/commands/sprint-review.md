Prepare a sprint review summary for the current (or just-completed) sprint.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team name for the composite command.

2. **Fetch all sprint data in one call:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprint-dashboard "<team>"`

   This returns: `sprint` (name, dates, daysElapsed, daysTotal), `summary` (done/total counts, donePoints/totalPoints), `byStatus` (issues grouped — use "done" group for completed, everything else for incomplete).

3. Separate completed (from `byStatus.done`) from incomplete items (all other groups).

4. Calculate velocity: sum of story points for completed items (from `summary.donePoints`).

## Output

### Sprint Review — [Sprint Name]
- Sprint dates, total duration
- Completion rate: X of Y items done (Z%)

### Completed Work
Table: key, type, summary, assignee, story points
Group by epic or theme if possible.

### Not Completed (Carryovers)
Table: key, type, summary, status, assignee, story points, reason (infer from status)

### Velocity
- Story points completed this sprint
- Items completed by type (stories, bugs, spikes)

### Key Accomplishments
Bullet-point summary of what was delivered (synthesized from completed item summaries).

### Observations
- Any patterns (e.g., lots of carryovers, one person doing most of the work)
- Items that were added mid-sprint
- Suggestions for next sprint

### Contextual Actions (Dynamic)

After presenting the summary, use `AskUserQuestion`: "What would you like to do?" with options:
- "Act on a carryover item" — drill into incomplete items
- "Add a retrospective comment to an item"
- "Highlight items for the sprint review"
- "Done (report looks good as-is)"

**If user picks "Act on a carryover item":**
Show the carryover table and ask which item. For the selected item:
1. Fetch transitions: `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh transitions <KEY>`
2. Check state: has points? blocked? assignee?
3. Build dynamic options:
   - List available transitions by name (e.g., "Move to next sprint", "Close")
   - "Re-estimate story points" / "Set story points"
   - "Reassign"
   - "Flag as blocked" / "Unflag blocker"
   - "Add a comment"
   - "Done (back to review)"
4. Execute with confirmation. Action loop until user returns.

**If user picks "Add a retrospective comment":**
Ask which item (from completed or carryover list). Draft and confirm comment. Post to Jira.

**If user picks "Highlight items":**
Use `AskUserQuestion` with multiSelect to pick items to demo/call out. Format a highlighted summary.

Always include clickable Jira URLs.

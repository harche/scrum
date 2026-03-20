Prepare a sprint review summary for the current (or just-completed) sprint.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team's sprint filter for all subsequent steps.

2. Find the active sprint for the selected team:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprints active` — filter for the team's sprint name pattern.

2. Get all sprint issues:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprint-issues <sprintId>`

3. Separate completed (Done/Closed/Verified) from incomplete items.

4. Calculate velocity: sum of story points for completed items.

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

### Review Prep
After presenting the summary, use `AskUserQuestion` to ask: "Any items to highlight for the sprint review?" with options:
- Select items to demo / call out
- Flag carryovers to discuss
- Note accomplishments to emphasize
- Report looks good as-is

Always include clickable Jira URLs.

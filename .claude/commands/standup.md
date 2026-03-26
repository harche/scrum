Prepare a summary for the weekly standup/grooming meeting.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team name for the composite command.

2. **Fetch all standup data in one call:**
   `bin/jira.sh standup-data "<team>"`

   This returns a single JSON blob with: `sprint` (id, name, dates, progress), `summary` (counts, points), `byAssignee` (issues grouped by assignee, sorted by status within each), `byStatus` (issues grouped by status), `blockers`, `atRisk`, `memberActivity`, `teamWorkload`.

3. **Display the output** (see Output below).

4. **Contextual Actions (Dynamic):**

   After displaying the sprint board, use `AskUserQuestion`: "What would you like to do?" with dynamic options:

   - "Act on a sprint item" — then ask which item number from the tables
   - "Run `/standup-github`" — for team GitHub activity
   - "Publish to GitHub Discussions"
   - "Done (no actions needed)"

   **If user picks an item**, resolve available actions from the API:
   a. Fetch transitions: `bin/jira.sh transitions <KEY>`
   b. Check state: has points? blocked? assignee?
   c. Build dynamic options:
      - List available transitions by name (from the transitions API)
      - Is blocked? → "Unflag blocker" : "Flag as blocked"
      - Has assignee? → "Reassign" : "Assign" (list roster members)
      - "Set story points" / "Update story points"
      - "Add a comment"
      - "Investigate (deep dive)"
      - "Done (back to standup)"
   d. Execute with confirmation. Action loop until user returns to standup.

## Output

### Sprint Progress
- Sprint name, days elapsed / total days, items done / total, points completed / total (from `sprint` and `summary`)

### Sprint Items
From `byAssignee` — one table per assignee (header: `#### Assignee Name`), items already sorted by status:

| # | Key | Summary | Status | Pts | Latest Comment |
|---|-----|---------|--------|-----|----------------|

- **Latest Comment:** From `latestComment` field — show as "_(date): body_". Truncate body to ~80 chars if longer. Show "—" if no comment.

### Blockers & Risks
- Items from `blockers` array (Blocked field set)
- Items from `atRisk` array
- Bugs with priority Blocker or Critical

Always include clickable Jira URLs and GitHub URLs.

## Publishing to GitHub Discussions (Optional)

When the user opts to publish, use `bin/gh-discussion.sh` to build and post the report:

1. **Build the report body** — write to a temp file the full standup report.

2. **Post:** `bin/gh-discussion.sh publish "Standup — YYYY-MM-DD | Sprint N Day X/Y" <body-file>`
   Show the returned discussion URL to the user.

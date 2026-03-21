Show progress on epics I'm contributing to in the current sprint.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team's sprint filter.

2. **Find the active sprint:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprints active` — filter for the selected team's sprint name pattern.

3. **Get my sprint issues:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprint-issues <sprintId>`
   Filter to items assigned to `harpatil@redhat.com`.

4. **Identify epics:**
   For each of my sprint items, check the Epic Link field (customfield_10014). Collect unique epic keys.

5. **Fetch each epic:**
   For each unique epic key, run:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh get <EPIC-KEY>`

6. **Get epic children:**
   For each epic, search for its child issues:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'cf[10014] = "<EPIC-KEY>" ORDER BY status ASC'`

## Output

### My Epics — [Sprint Name]

For each epic, show:

#### [Epic Key] — [Epic Summary]
Status: [epic status] | Assignee: [epic owner]

**Progress:**
- Total children: X
- Done/Closed: Y (Z%)
- In Progress: N
- To Do: M

**My items in this epic:**
| # | Key | Summary | Status | Pts |
|---|-----|---------|--------|-----|

**Other contributors' items (this sprint):**
| # | Key | Summary | Status | Assignee | Pts |
|---|-----|---------|--------|----------|-----|

A simple progress bar visualization: `[=========>    ] 65%`

### Overall
- Total epics I'm contributing to: N
- Epics nearing completion (>80%): list
- Epics at risk (many items still To Do): list

Always include clickable Jira URLs for every issue and epic key.

### Contextual Actions (Dynamic)

After presenting epics, use `AskUserQuestion` to ask: "Which epic or item would you like to act on?" with each epic number and child issue number as options, plus "Done (no actions needed)".

When the user picks an item (epic or child issue), resolve available actions from the API:

1. **Fetch available transitions:** `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh transitions <SELECTED-KEY>`
2. **Check current state** from the already-fetched data:
   - Has story points (customfield_10028)? → offer "Update story points" : "Set story points"
   - Is blocked (customfield_10517 set)? → offer "Unflag blocker" : "Flag as blocked"
   - Has assignee? → offer "Reassign" : "Assign"

3. **Build dynamic options** for `AskUserQuestion`: "What would you like to do with [KEY]?"
   - List each available transition by name (from the transitions API)
   - Include the state-based options from step 2
   - Always include: "Add a comment", "Investigate (deep dive)", "Done (back to epics)"

4. **Execute the chosen action** (with confirmation via `AskUserQuestion` for any write operation).

5. **Action loop:** After executing an action, re-fetch transitions and state, then offer next actions. When the user picks "Done (back to epics)", return to the item selection list. Continue until the user picks "Done (no actions needed)" at the top level.

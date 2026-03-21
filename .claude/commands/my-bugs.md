Show all bugs assigned to me, sorted by severity, age, and customer impact.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team's bug components for all queries.

2. **My open bugs:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPBUGS AND component in (<team bug components>) AND assignee = "harpatil@redhat.com" AND status not in (CLOSED, Verified, Done) ORDER BY priority ASC, created ASC'`

3. **Check for customer escalations** among my bugs:
   Look for issues with SFDC Cases Counter (customfield_10978) populated.

4. **Check for release blocker flags:**
   Look for issues with Release Blocker (customfield_10847) set.

## Output

### My Bugs — [Team Name]

### Summary
- Total open bugs assigned to me
- By priority: Blocker / Critical / Major / Normal / Minor / Undefined
- Customer escalations count
- Release blocker proposals count

### Customer Escalations (if any)
| # | Key | Summary | Priority | Status | Severity | Cases |
|---|-----|---------|----------|--------|----------|-------|

### Release Blockers (if any)
| # | Key | Summary | Priority | Status | Blocker Flag |
|---|-----|---------|----------|--------|-------------|

### All My Bugs
| # | Key | Summary | Priority | Status | Age (days) | Target Version |
|---|-----|---------|----------|--------|------------|----------------|

Sort by: priority (Blocker first), then by age (oldest first).

Always include clickable Jira URLs for every issue key.

### Contextual Actions (Dynamic)

After presenting bugs, use `AskUserQuestion` to ask: "Which bug would you like to act on?" with each item number as an option, plus "Done (no actions needed)".

When the user picks a bug, resolve that bug's available actions from the API:

1. **Fetch available transitions:** `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh transitions <SELECTED-KEY>`
2. **Check current state** from the already-fetched bug data:
   - Is blocked (customfield_10517 set)? → offer "Unflag blocker" : "Flag as blocked"
   - Has SFDC cases (customfield_10978)? → offer "View customer cases"
   - Is release blocker (customfield_10847)? → note in the options
   - Current status determines available flow (NEW→ASSIGNED→POST→Modified→ON_QA→Verified→CLOSED)

3. **Build dynamic options** for `AskUserQuestion`: "What would you like to do with [KEY]?"
   - List each available transition by name (from the transitions API, e.g., "Move to ASSIGNED", "Move to POST")
   - Include the state-based options from step 2
   - Always include: "Add a comment", "Investigate (deep dive)", "Done (back to bug list)"

4. **Execute the chosen action** (with confirmation via `AskUserQuestion` for any write operation).

5. **Action loop:** After executing an action, re-fetch transitions and state, then offer next actions. When the user picks "Done (back to bug list)", return to the bug selection list. Continue until the user picks "Done (no actions needed)" at the top level.

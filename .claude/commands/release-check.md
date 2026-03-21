Check release readiness for Node components.

Takes an optional argument: OCP version (e.g., 4.22). If not provided, discover the most common active fixVersion from open OCPNODE issues.

Argument: $ARGUMENTS (optional OCP version, e.g., "4.22")

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team's bug components for all queries below.

2. If no version provided, discover it:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPNODE AND fixVersion is not EMPTY AND status not in (Closed, Done) AND component in (<team bug components>)' `
   Pick the most common fixVersion.

3. **Approved blockers**:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPBUGS AND component in (<team bug components>) AND "Release Blocker" = "Approved" AND fixVersion ~ "<version>" AND status not in (CLOSED, Verified, Done)'`

3. **Proposed blockers**:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPBUGS AND component in ("Node / Device Manager", "Node / Instaslice-operator") AND "Release Blocker" = "Proposed" AND fixVersion ~ "<version>" AND status not in (CLOSED, Verified, Done)'`

4. **Open bugs for this version**:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPBUGS AND component in ("Node / Device Manager", "Node / Instaslice-operator") AND fixVersion ~ "<version>" AND status not in (CLOSED, Verified, Done) ORDER BY priority DESC'`

5. **Epic completion**:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPNODE AND issuetype = Epic AND fixVersion ~ "<version>" AND component in ("Node / Device Manager", "Node / Instaslice-operator") AND status not in (Closed, Done)'`

## Output

### Release Readiness — OCP [version]

### Blockers
- Approved blockers table (CRITICAL — must fix)
- Proposed blockers table (needs triage decision)

### Open Bugs
Table: key, summary, priority, status, assignee

### Epic Status
Table: key, summary, status, % children done (if possible to infer)

### Assessment
- Ship/no-ship recommendation based on blocker count and severity
- Key risks

### Contextual Actions (Dynamic)

Present blockers and high-risk items interactively. For each item:

1. **Fetch available transitions:** `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh transitions <KEY>`
2. **Check current state:**
   - Is blocked (customfield_10517)? → offer "Unflag blocker" : "Flag as blocked"
   - Has assignee? → offer "Reassign" : "Assign" (list roster members)
   - Is release blocker approved/proposed (customfield_10847)? → offer "Change release blocker status"
   - Has SFDC cases? → offer "View customer cases"

3. **Build dynamic options** for `AskUserQuestion`: "What to do with [KEY]?"
   - List each available transition by name (from the transitions API)
   - "Escalate (add comment + change priority)"
   - Include the state-based options from step 2
   - "Add a comment"
   - "Investigate (deep dive)"
   - "Mark as accepted risk" (add comment noting acceptance)
   - "Skip"

4. **Execute the chosen action** (with confirmation). Action loop until user skips.

After all blockers reviewed, offer final actions:
- "Act on an open bug from the list" — then select and offer per-item dynamic actions
- "Run `/bug-triage`" — full triage session
- "Done"

Always include clickable Jira URLs.

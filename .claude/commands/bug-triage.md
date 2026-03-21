Run a bug triage session.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team's bug components for all queries below.

2. **Untriaged bugs** — priority not set:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPBUGS AND component in (<team bug components>) AND priority = Undefined AND status not in (CLOSED, Verified, Done) ORDER BY created DESC'`

3. **Unassigned bugs** — no owner:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPBUGS AND component in (<team bug components>) AND assignee is EMPTY AND status not in (CLOSED, Verified, Done) ORDER BY priority DESC'`

4. **Blocker proposals** — flagged as potential release blockers:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPBUGS AND component in (<team bug components>) AND "Release Blocker" = "Proposed" AND status not in (CLOSED, Verified, Done)'`

5. **Customer escalations** — has linked support cases:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPBUGS AND component in (<team bug components>) AND "SFDC Cases Counter" is not EMPTY AND status not in (CLOSED, Verified, Done)'`

5. **New bugs this week**:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPBUGS AND component in ("Node / Device Manager", "Node / Instaslice-operator") AND created >= -7d ORDER BY created DESC'`

6. **All open bugs summary**:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPBUGS AND component in ("Node / Device Manager", "Node / Instaslice-operator") AND status not in (CLOSED, Verified, Done) ORDER BY priority DESC'`

## Output

Present each section as a table with: key, summary, priority, status, assignee, created date.

### Triage Summary
- Total open bugs
- Untriaged count
- Unassigned count
- Blocker proposals
- Customer escalations
- New this week

### Contextual Actions (Dynamic)

Present bugs interactively, one category at a time (untriaged, unassigned, blocker proposals, customer escalations, new this week). For each category:

1. Show the table of bugs
2. Use `AskUserQuestion`: "Which bug would you like to act on?" with item numbers as options + "Skip to next category"

When the user picks a bug, resolve that bug's available actions from the API:

a. **Fetch available transitions:** `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh transitions <KEY>`
b. **Check current state** from the already-fetched bug data:
   - Has assignee? → offer "Reassign" : "Assign" (list roster members from both roster files as sub-options)
   - Is blocked? → offer "Unflag blocker" : "Flag as blocked"
   - Has SFDC cases? → offer "View customer cases"
   - Is release blocker proposed? → offer "Approve as release blocker" / "Reject as release blocker"
   - Has priority set? → offer "Change priority" : "Set priority"
   - Current sprint? → note; if not in sprint → offer "Add to sprint" (list active/future sprints)

c. **Build dynamic options** for `AskUserQuestion`: "What would you like to do with [KEY]?"
   - List each available transition by name (from the transitions API)
   - Include the state-based options from steps b
   - Always include: "Add a comment", "Investigate (deep dive)", "Skip (back to list)"

d. **Execute the chosen action** (with confirmation via `AskUserQuestion`).
e. **Action loop:** After executing, re-fetch transitions + state, offer next actions. Continue until user picks "Skip" to return to the category.

After all categories, show the Action Items summary:
- For each untriaged/unassigned bug, suggest: assign to whom (based on related component/area), suggested priority (based on severity/impact keywords in summary)

Always include clickable Jira URLs.

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

### Action Items
For each untriaged/unassigned bug, suggest: assign to whom (based on related component/area), suggested priority (based on severity/impact keywords in summary).

Always include clickable Jira URLs.

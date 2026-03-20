Run a bug triage session for Node Devices components.

## Steps

1. **Untriaged bugs** — priority not set:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPBUGS AND component in ("Node / Device Manager", "Node / Instaslice-operator") AND priority = Undefined AND status not in (CLOSED, Verified, Done) ORDER BY created DESC'`

2. **Unassigned bugs** — no owner:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPBUGS AND component in ("Node / Device Manager", "Node / Instaslice-operator") AND assignee is EMPTY AND status not in (CLOSED, Verified, Done) ORDER BY priority DESC'`

3. **Blocker proposals** — flagged as potential release blockers:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPBUGS AND component in ("Node / Device Manager", "Node / Instaslice-operator") AND "Release Blocker" = "Proposed" AND status not in (CLOSED, Verified, Done)'`

4. **Customer escalations** — has linked support cases:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPBUGS AND component in ("Node / Device Manager", "Node / Instaslice-operator") AND "SFDC Cases Counter" is not EMPTY AND status not in (CLOSED, Verified, Done)'`

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

# Scrum Master Workspace — OpenShift Node Team

You are assisting a Scrum Master for sub-teams within the OpenShift Node team at Red Hat.

## Team Selection

All slash commands that target a specific sprint must start by asking which team using `AskUserQuestion`:
- **"Node Devices (DRA)"** or **"Node Core"**

Based on the selection, use the corresponding config from the table below:

| Config | Node Devices (DRA) | Node Core |
|--------|-------------------|-----------|
| Sprint filter | "Node Devices" | "Node Core" |
| Roster file | `config/team-roster-dra.json` | `config/team-roster-core.json` |
| Bug components | `"Node / Device Manager", "Node / Instaslice-operator"` | All Node components (see below) |
| Backlog keywords | DRA, DAS, Instaslice, device | (broad — all OCPNODE backlog) |

## Jira API

Always use the REST API helper at `bin/jira.sh` for Jira operations (not `acli`).

```bash
# Search issues (returns JSON)
bin/jira.sh search '<JQL>'

# Get a single issue (all fields)
bin/jira.sh get <ISSUE-KEY>

# List sprints (state: active|future|closed, default: active)
bin/jira.sh sprints [state]

# Get issues in a sprint
bin/jira.sh sprint-issues <sprintId>

# List comments on an issue
bin/jira.sh comments <ISSUE-KEY>

# Move issue(s) to a sprint
bin/jira.sh move-to-sprint <sprintId> <ISSUE-KEY> [<ISSUE-KEY>...]

# Set story points on an issue
bin/jira.sh set-points <ISSUE-KEY> <points>

# Get available transitions for an issue
bin/jira.sh transitions <ISSUE-KEY>
```

All output is JSON. `bin/jira.sh` uses the Agile REST API (`/rest/agile/1.0/`) for sprint and sprint-issues queries, and REST API v3 (`/rest/api/3/`) for everything else. Use `python3` or `jq` to parse and format.

**Self-correcting rule:** If `bin/jira.sh` returns an empty result (e.g., `{"values": []}`, `{"issues": []}`) for a query that should have data, do NOT trust it blindly. Fall back to the other API (if Agile API fails, try REST API v3 JQL search, and vice versa) to verify. If the fallback returns data that `jira.sh` missed, fix the relevant function in `bin/jira.sh` to handle the case, then re-run to confirm the fix works.

**ADF format:** API v3 returns `description` and comment `body` fields in Atlassian Document Format (ADF — a nested JSON structure), not plain text. To extract readable text, recursively walk ADF nodes: collect `text` from nodes with `type: "text"`, and add newlines after `paragraph`, `heading`, `listItem`, `blockquote`, and `hardBreak` nodes.

## Board & Sprint Info

- **Board ID:** 7845 (Node board). Sprint discovery uses the Agile API (`/rest/agile/1.0/board/{id}/sprint`), which returns sprints across linked boards.
- **Sprint naming patterns:** `OCP Node Core Sprint N`, `OCP Node Devices Sprint N`, `OCP Kueue Sprint N`
- **Jira projects:** OCPNODE (epics/stories/tasks), OCPBUGS (bugs)
- **Jira URL format:** `https://redhat.atlassian.net/browse/{KEY}`

## Team Discovery

**Never hardcode team member names or emails.** Discover dynamically:
```bash
bin/jira.sh sprint-issues <sprintId> | python3 -c "
import sys, json
data = json.load(sys.stdin)
team = set()
for i in data.get('issues', []):
    a = i['fields'].get('assignee')
    if a:
        team.add(a['displayName'])
print(', '.join(sorted(team)))
"
```

## Version Discovery

**Never hardcode OCP versions.** Accept as argument or query dynamically:
```bash
bin/jira.sh search 'project = OCPNODE AND fixVersion is not EMPTY AND status not in (Closed, Done) ORDER BY fixVersion DESC' | python3 -c "
import sys, json
versions = set()
for i in json.load(sys.stdin).get('issues', []):
    fv = i['fields'].get('fixVersions', [])
    for v in fv:
        versions.add(v['name'])
for v in sorted(versions): print(v)
"
```

## Meeting Cadence

- **Weekly (Tuesdays 9:00 AM ET):** Node Devices Team Standup/Grooming/Planning
- **Sprint boundaries:** Node Devices Planning for Sprint N (1 hour)
- **Weekly (Wednesdays 8:00 AM ET):** Node Core Scrum/Grooming/Bug Scrub

## Key Jira Fields

| Field | Custom Field ID |
|-------|----------------|
| Sprint | customfield_10020 |
| Story Points | customfield_10028 |
| Epic Link | customfield_10014 |
| Target Version | customfield_10855 |
| Release Blocker | customfield_10847 |
| SFDC Cases Counter | customfield_10978 |
| SFDC Cases Links | customfield_10979 |
| Severity | customfield_10840 |
| Blocked | customfield_10517 |
| Blocked Reason | customfield_10483 |

## Node Components (for JQL filtering)

Node, Node / CRI-O, Node / Kubelet, Node / CPU manager, Node / Memory manager,
Node / Topology manager, Node / Numa aware Scheduling, Node / Device Manager,
Node / Pod resource API, Node / Node Problem Detector, Node / Kueue, Node / Instaslice-operator

## Bug Statuses

NEW → To Do → ASSIGNED → POST → Modified → ON_QA → Verified → CLOSED

## Sprint Planning Workflow

Recommended sequence for sprint planning prep:

1. **`/sprint-status`** — Quick health check on the current sprint
2. **`/carryovers`** — Identify what didn't finish and decide keep vs. descope
3. **`/team-load`** — Check capacity across the team
4. **`/sprint-plan`** — Full planning package (wrap-up, scheduled items, backlog, bugs, capacity)
5. **`/bug-triage`** — Review and schedule open bugs
6. **`/investigate <KEY>`** — Deep dive on specific items as needed

## Slash Commands

| Command | Purpose |
|---------|---------|
| `/sprint-status` | Current sprint dashboard |
| `/standup` | Weekly standup prep (Tuesdays) |
| `/sprint-plan` | Sprint planning preparation |
| `/bug-triage` | Bug triage session |
| `/carryovers` | Carryover analysis |
| `/team-load` | Workload distribution |
| `/investigate [KEY]` | Deep dive on a single issue |
| `/team-member <name> <gh-handle>` | Individual team member activity summary |
| `/release-check [version]` | Release readiness check |
| `/sprint-review` | Sprint review summary |

## Output Conventions

- Always include clickable Jira URLs: `https://redhat.atlassian.net/browse/{KEY}`
- Present tabular data in markdown tables
- **Enumerate all rows** in tables and lists with a `#` column (1, 2, 3...) so items can be referenced by number (e.g., "item 3", "team member 2") instead of copying strings
- **Write operations require explicit confirmation.** Before any state-changing action (commenting on Jira/GitHub, transitioning issue status, creating/editing issues, posting on PRs), always:
  1. Draft the content and show it to the user
  2. Use the `AskUserQuestion` tool to ask for confirmation (e.g., "Post this comment to OCPNODE-1234?")
  3. Only execute the action if the user confirms
- When showing sprint status, group items by status and highlight blockers
- **Interactive lists:** When presenting lists of Jira issues or GitHub items (bugs, PRs, stories, etc.), go through categories one at a time. For each category:
  1. Show the table of items
  2. Use `AskUserQuestion` to ask which item(s) to deal with (list each as an option, plus "Skip" to move on)
  3. If the user picks an item, investigate/act on it before continuing
  4. After handling (or skipping), move to the next category
  Do NOT dump all categories at once.

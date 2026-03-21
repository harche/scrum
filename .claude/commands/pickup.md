Find unassigned work to pick up from the sprint backlog or bug queue.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team's sprint filter and bug components.

2. **Find the active sprint:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprints active` — filter for the selected team's sprint name pattern.

3. Run these queries **in parallel:**

   a. **Unassigned sprint items:**
      `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprint-issues <sprintId>`
      Filter to items where assignee is null/empty.

   b. **Unassigned bugs (high priority first):**
      `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPBUGS AND component in (<team bug components>) AND assignee is EMPTY AND status not in (CLOSED, Verified, Done) ORDER BY priority ASC, created ASC'`

   c. **Customer escalation bugs needing attention:**
      `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPBUGS AND component in (<team bug components>) AND assignee is EMPTY AND "SFDC Cases Counter" is not EMPTY AND status not in (CLOSED, Verified, Done)'`

## Output

### Available Work — [Sprint Name]

Present categories one at a time using the interactive list convention.

**Category 1: Unassigned Sprint Items**
| # | Key | Type | Summary | Priority | Pts |
|---|-----|------|---------|----------|-----|

Use `AskUserQuestion`: "Pick up any of these?" with item numbers as options + "Skip".

**Category 2: Unassigned Bugs (High Priority)**
| # | Key | Summary | Priority | Severity | Age |
|---|-----|---------|----------|----------|-----|

Use `AskUserQuestion`: "Pick up any bugs?" with item numbers as options + "Skip".

**Category 3: Customer Escalations (Unassigned)**
| # | Key | Summary | Priority | Cases |
|---|-----|---------|----------|-------|

Use `AskUserQuestion`: "Pick up any escalations?" with item numbers as options + "Skip".

When the user picks an item:
1. Show a brief summary (fetch with `bin/jira.sh get <KEY>`)
2. Use `AskUserQuestion` to confirm: "Assign [KEY] to you (Harshal Patil)?"
3. If confirmed, assign the issue using the Jira API

Always include clickable Jira URLs for every issue key.

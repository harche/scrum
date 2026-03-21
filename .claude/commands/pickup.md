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

When the user picks an item, resolve that item's available actions from the API:

1. **Fetch the issue:** `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh get <KEY>` — show brief summary
2. **Fetch available transitions:** `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh transitions <KEY>`
3. **Check current state:**
   - Has story points (customfield_10028)? → offer "Set story points after assigning"
   - Current sprint? → note which sprint it's in
   - Is blocked? → note blocker status

4. **Build dynamic options** for `AskUserQuestion`: "What would you like to do with [KEY]?"
   - "Assign to me (Harshal Patil)" — primary action
   - "Assign to me + set story points" — if no points set
   - "Assign to me + move to In Progress" — if transition available
   - List other available transitions by name (from the transitions API)
   - "Investigate (deep dive)"
   - "Skip (back to list)"

5. **Execute the chosen action** (with confirmation via `AskUserQuestion` for any write operation).

6. **Action loop:** After assigning, re-fetch transitions and offer follow-up actions (e.g., set points, transition status, add comment). Continue until user picks "Skip" to return to the item list, or "Done" to exit.

Always include clickable Jira URLs for every issue key.

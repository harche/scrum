Find unassigned work to pick up from the sprint backlog or bug queue.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md).

2. **Fetch all available work:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh pickup-data "<team>"`

   Returns: `sprint` (id, name), `unassignedSprintItems[]`, `unassignedBugs[]`, `customerEscalations[]`, `summary` (sprintItems, bugs, escalations counts).

3. Render categories directly from the returned JSON.

## Output

### Available Work — `sprint.name`

Present categories one at a time.

**Category 1: Unassigned Sprint Items** (from `unassignedSprintItems[]`)
| # | Key | Type | Summary | Priority | Pts |

Use `AskUserQuestion`: "Pick up any of these?" with numbers + "Skip".

**Category 2: Unassigned Bugs** (from `unassignedBugs[]`)
| # | Key | Summary | Priority | Status |

Use `AskUserQuestion`: "Pick up any bugs?" with numbers + "Skip".

**Category 3: Customer Escalations** (from `customerEscalations[]`)
| # | Key | Summary | Priority | Cases |

Use `AskUserQuestion`: "Pick up any escalations?" with numbers + "Skip".

When user picks an item:
1. Fetch transitions: `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh transitions <KEY>`
2. Build dynamic options:
   - "Assign to me (Harshal Patil)"
   - "Assign to me + set story points" (if no points)
   - "Assign to me + move to In Progress" (if transition available)
   - List other transitions
   - "Investigate (deep dive)" / "Skip"
3. Execute with confirmation. Action loop until done.

Always include clickable Jira URLs.

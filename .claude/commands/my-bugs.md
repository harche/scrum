Show all bugs assigned to me, sorted by severity, age, and customer impact.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md).

2. **Fetch my bugs data:**
   `bin/jira.sh my-bugs-data "<team>"`

   Returns: `team`, `summary` (total, byPriority, customerEscalations, releaseBlockers), `customerEscalations[]`, `releaseBlockers[]`, `allBugs[]` (each with key, summary, status, priority, points, fixVersions, blocked, sfdcCaseCount, releaseBlocker).

3. Render tables directly from the returned JSON.

## Output

### My Bugs — `team`

### Summary
From `summary`: total, by priority breakdown, escalations count, release blockers count.

### Customer Escalations (if `customerEscalations` non-empty)
| # | Key | Summary | Priority | Status | Cases |

### Release Blockers (if `releaseBlockers` non-empty)
| # | Key | Summary | Priority | Status | Blocker Flag |

### All My Bugs (from `allBugs`)
| # | Key | Summary | Priority | Status | Fix Version |

Always include clickable Jira URLs.

### Contextual Actions (Dynamic)

Use `AskUserQuestion`: "Which bug to act on?" with item numbers + "Done".

When user picks a bug:
1. Fetch transitions: `bin/jira.sh transitions <KEY>`
2. Build dynamic options from transitions + state
3. Execute with confirmation. Action loop until done.

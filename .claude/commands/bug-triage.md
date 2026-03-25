Run a bug triage session across all Node components.

## Steps

1. **Fetch all bug data (no team selection needed):**
   `bin/jira.sh bug-overview all`

   This searches ALL Node components and both team rosters. Returns: `summary` (totalOpen, untriaged, unassigned, blockerProposals, newThisWeek, missingComponent, excludedExternalCVEs), and arrays: `untriaged`, `unassigned`, `blockerProposals`, `newThisWeek`, `missingComponent`, `allOpen`.

## Output

### Triage Summary
From `summary`: Total open bugs, Untriaged, Unassigned, Blocker proposals, New this week, Missing/out-of-scope component, Excluded external CVEs.

### All Categories — Show Everything Up Front

Show ALL non-empty category tables below in one pass. Do NOT use one-at-a-time interactive flow — show them all so the user sees the full picture. **Skip categories with 0 items silently.**

**Category 1: Untriaged Bugs** (from `untriaged[]`)
Bugs with priority Undefined/Unprioritized — need priority set.
| # | Key | Summary | Status | Assignee | Components |

**Category 2: Unassigned Bugs** (from `unassigned[]`)
Bugs with no owner (or assigned to bot account) — need assignment.
| # | Key | Summary | Priority | Status | Components |

**Category 3: Blocker Proposals** (from `blockerProposals[]`)
Bugs proposed as release blockers — need approve/reject decision.
| # | Key | Summary | Priority | Status | Assignee |

**Category 4: Missing/Out-of-Scope Component** (from `missingComponent[]`)
Bugs assigned to team members but tagged with non-Node components or no component at all.
| # | Key | Summary | Priority | Status | Assignee | Components |

**Category 6: New Bugs This Week** (from `newThisWeek[]`)
Bugs filed in the last 7 days.
| # | Key | Summary | Priority | Status | Assignee |

### Interactive Actions

After showing all tables, use `AskUserQuestion`: "Which bug would you like to act on? (enter the key, e.g. OCPBUGS-79483)" with these options:
- "Pick a bug to act on" — user will type the key
- "Done — no actions needed"

When the user picks a bug:

a. **Fetch available transitions:** `bin/jira.sh transitions <KEY>`
b. **Check current state** from the bug data:
   - Has assignee? → offer "Reassign" : "Assign" (list roster members)
   - Is blocked? → offer "Unflag blocker" : "Flag as blocked"
   - Has SFDC cases? → offer "View customer cases"
   - Is release blocker proposed? → offer "Approve as release blocker" / "Reject as release blocker"
   - Has priority set? → offer "Change priority" : "Set priority"
   - Has component? → offer "Set component" if empty
   - Current sprint? → note; if not in sprint → offer "Add to sprint"

c. **Build dynamic options** for `AskUserQuestion`: "What would you like to do with [KEY]?"
   - List each available transition by name (from the transitions API)
   - Include the state-based options from step b
   - Always include: "Add a comment", "Investigate (deep dive)", "Done with this bug"

d. **Execute the chosen action** (with confirmation via `AskUserQuestion`).
e. **Action loop:** After executing, re-fetch transitions + state, offer next actions. Continue until user picks "Done with this bug".
f. After finishing with one bug, ask again: "Which bug would you like to act on next?" — repeat until user picks "Done — no actions needed".

Always include clickable Jira URLs.

Run a bug triage session across all Node components.

## Steps

1. **Fetch all bug data (no team selection needed):**
   `bin/jira.sh bug-overview all`

   This searches ALL Node components and both team rosters. Returns: `summary` (totalOpen, untriaged, unassigned, blockerProposals, customerEscalations, newThisWeek, missingComponent), and arrays: `untriaged`, `unassigned`, `blockerProposals`, `customerEscalations`, `newThisWeek`, `missingComponent`, `allOpen`.

## Output

### Triage Summary
From `summary`: Total open bugs, Untriaged, Unassigned, Blocker proposals, Customer escalations, New this week, Missing/out-of-scope component.

### Interactive Triage — Category by Category

Present each category below **one at a time, in this order**. For each: show the table if non-empty, then use `AskUserQuestion` to let the user act on items or skip. **Skip categories with 0 items silently.**

---

**Category 1: Untriaged Bugs** (from `untriaged[]`)
Bugs with priority Undefined/Unprioritized — need priority set.
| # | Key | Summary | Priority | Status | Assignee | Components |

---

**Category 2: Unassigned Bugs** (from `unassigned[]`)
Bugs with no owner — need assignment.
| # | Key | Summary | Priority | Status | Components |

---

**Category 3: Blocker Proposals** (from `blockerProposals[]`)
Bugs proposed as release blockers — need approve/reject decision.
| # | Key | Summary | Priority | Status | Assignee |

---

**Category 4: Customer Escalations** (from `customerEscalations[]`)
Bugs with linked SFDC support cases — customer-facing.
| # | Key | Summary | Priority | Status | Assignee |

---

**Category 5: Missing/Out-of-Scope Component** (from `missingComponent[]`)
Bugs assigned to team members but tagged with non-Node components or no component at all. These fall through component-based filters and need attention — may need component correction or reassignment.
| # | Key | Summary | Priority | Status | Assignee | Components |

---

**Category 6: New Bugs This Week** (from `newThisWeek[]`)
Bugs filed in the last 7 days.
| # | Key | Summary | Priority | Status | Assignee |

---

### Per-Item Actions

After showing each category table, use `AskUserQuestion`: "Which bug would you like to act on?" with item numbers + "Skip to next category".

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
   - Always include: "Add a comment", "Investigate (deep dive)", "Skip (back to list)"

d. **Execute the chosen action** (with confirmation via `AskUserQuestion`).
e. **Action loop:** After executing, re-fetch transitions + state, offer next actions. Continue until user picks "Skip".

### After All Categories

Show Action Items summary:
- For each untriaged/unassigned bug, suggest: assign to whom, suggested priority
- For each missing-component bug, suggest: correct component to set

Always include clickable Jira URLs.

Fetch GitHub activity for a specific team member.

Arguments: $ARGUMENTS
Format: `<name-or-partial>`
Example: `/team-member-github Sai` or `/team-member-github Aditi`

Look up the GitHub handle by matching the name argument (case-insensitive partial match) against roster keys in both `config/team-roster-dra.json` and `config/team-roster-core.json`.

## Steps

1. **Resolve GitHub handle** from roster files.

2. **Fetch member's GitHub activity:**
   `bin/gh-activity.sh member-prs <github-handle>`

   Returns: `authored[]` (PRs with repo, title, state, url, reviewDecision, mergedAt), `reviewed[]` (PRs reviewed), `issues[]` (GitHub issues), `summary` (authored, reviewed, issues counts).

3. Render directly from the returned JSON.

## Output

### GitHub Activity — [Name] (@[handle])

### Summary
From `summary`: authored PRs, reviewed PRs, issues.

### Authored PRs (from `authored[]`)
| # | Repo | Title | State | Review Status | URL |

### PRs Reviewed (from `reviewed[]`)
| # | Repo | Title | Author | State | URL |

### GitHub Issues (from `issues[]`)
| # | Repo | Title | State | URL |

### Activity Narrative
Synthesize a brief summary of what this person has been doing on GitHub this week.

Always include clickable GitHub URLs.

### Contextual Actions (Dynamic)

Use `AskUserQuestion`: "What to do?" with:
- "View a specific PR" → fetch state, offer merge/review/comment actions
- "Run `/team-member <name>`" for Jira activity
- "Done"

Fetch GitHub activity for all team members for the standup.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team's roster file.

2. **Fetch team GitHub activity:**
   `bin/gh-activity.sh team-prs config/team-roster-<team>.json`

   Use `config/team-roster-dra.json` for Node Devices, `config/team-roster-core.json` for Node Core.

   Returns: `members[]` (each with name, github, authored count, reviewed count, commented count, `prs[]` with top 5 recent PRs), `summary` (totalMembers).

3. Render directly from the returned JSON.

## Output

### GitHub Activity — [Team Name]

### Team Summary (from `members[]`)
| # | Member | GitHub | PRs Authored | PRs Reviewed | PRs Commented |

### Per-Member Detail
For each member with activity (authored + reviewed > 0):

**[Name] (@[github]):**
- Authored: `authored` PRs, Reviewed: `reviewed`, Commented: `commented`
- Recent PRs (from `prs[]`):
  | Repo | Title | State | URL |

Synthesize a brief 1-2 sentence activity narrative per active member.

Always include clickable GitHub URLs.

### Contextual Actions (Dynamic)

Use `AskUserQuestion`: "What to do?" with:
- "Drill into [member]'s PRs" → run `bin/gh-activity.sh member-prs <handle>` for full detail
- "View a specific PR" → fetch state, offer actions
- "Done"

Show progress on epics I'm contributing to in the current sprint.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md).

2. **Fetch epic progress data:**
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh epic-progress "<team>"`

   Returns: `sprint` (id, name), `epics[]` (each with key, summary, status, assignee, `progress` {total, done, inProgress, toDo, percent}, `myItems[]`, `otherItems[]`, `allChildren[]`), `summary` (totalEpics, nearComplete[], atRisk[]).

3. Render directly from the returned JSON.

## Output

### My Epics — `sprint.name`

For each epic in `epics[]`:

#### [epic.key] — [epic.summary]
Status: `epic.status` | Assignee: `epic.assignee`

**Progress:** (from `epic.progress`)
- Total: `total`, Done: `done` (`percent`%), In Progress: `inProgress`, To Do: `toDo`
- Progress bar: `[=========>    ] 65%`

**My items in this epic:** (from `epic.myItems[]`)
| # | Key | Summary | Status | Pts |

**Other contributors' items:** (from `epic.otherItems[]`)
| # | Key | Summary | Status | Assignee | Pts |

### Overall (from `summary`)
- Total epics: `totalEpics`
- Near completion (>80%): `nearComplete[]`
- At risk: `atRisk[]`

Always include clickable Jira URLs.

### Contextual Actions (Dynamic)

Use `AskUserQuestion`: "Which epic or item to act on?" with numbers + "Done".

When user picks an item:
1. Fetch transitions: `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh transitions <KEY>`
2. Build dynamic options from transitions + state
3. Execute with confirmation. Action loop until done.

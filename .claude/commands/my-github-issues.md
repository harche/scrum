Show my GitHub issues — filed by me, assigned to me, and ones I've commented on recently.

The user's GitHub handle is `harche` (from roster files).

## Steps

1. **Fetch all issue data:**
   `bin/gh-activity.sh my-issues harche`

   Returns: `authored[]`, `assigned[]`, `commented[]` (each with repo, title, state, url, author, labels), `summary` (authored, assigned, commented counts).

2. Render directly from the returned JSON.

## Output

### My GitHub Issues

### Summary
From `summary`: authored, assigned, commented counts.

### Authored by Me (from `authored[]`)
| # | Repo | Title | State | Labels | URL |

### Assigned to Me (from `assigned[]`)
| # | Repo | Title | State | Labels | URL |

### Recently Commented (from `commented[]`)
| # | Repo | Title | State | Author | URL |

Always include clickable GitHub URLs.

### Contextual Actions (Dynamic)

Use `AskUserQuestion`: "Which issue to act on?" with numbers + "Done".

When user picks an issue:
- "View in browser"
- "Add a comment"
- "Close issue" (if open)
- "Done"
Execute with confirmation.

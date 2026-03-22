Show PRs waiting for my review, prioritized by age and importance.

The user's GitHub handle is `harche` (from roster files).

## Steps

1. **Fetch review queue data:**
   `bin/gh-activity.sh review-queue harche`

   Returns: `reviewRequested[]` (sorted oldest first, with repo, title, url, author, ageDays, isDraft), `mentioned[]`, `summary` (reviewRequested, mentioned counts).

2. Render directly from the returned JSON.

## Output

### Review Queue

### Summary
From `summary`: review requested count, mentioned count.

### PRs Requesting My Review (from `reviewRequested[]`, sorted oldest first)
| # | Repo | Title | Author | Age (days) | Draft? | URL |

### Mentioned (from `mentioned[]`)
| # | Repo | Title | Author | URL |

Always include clickable GitHub URLs.

### Contextual Actions (Dynamic)

Use `AskUserQuestion`: "Which PR to review?" with numbers + "Done".

When user picks a PR:
1. Fetch state: `gh pr view <URL> --json state,reviewDecision,statusCheckRollup,isDraft,mergeable,additions,deletions`
2. Build options: "Start review", "Approve", "Request changes", "View diff", "Open in browser", "Done"
3. Execute with confirmation. Action loop until done.

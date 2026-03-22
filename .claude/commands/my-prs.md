Show my open PRs across GitHub — review status, CI status, merge readiness, plus PRs where I'm a requested reviewer.

The user's GitHub handle is `harche` (from roster files).

## Steps

1. **Fetch all PR data:**
   `bin/gh-activity.sh my-prs harche`

   Returns: `authoredOpen[]` (with repo, title, state, url, reviewDecision, isDraft), `authoredMerged[]` (recently merged), `reviewRequested[]` (PRs requesting my review), `summary` (openPRs, recentlyMerged, reviewRequests counts).

2. Render directly from the returned JSON.

## Output

### My PRs

### Summary
From `summary`: open PRs, recently merged (7d), review requests for me.

### My Open PRs (from `authoredOpen[]`)
| # | Repo | Title | Review Status | Draft? | URL |

### Recently Merged (from `authoredMerged[]`)
| # | Repo | Title | Merged At | URL |

### Review Requests for Me (from `reviewRequested[]`)
| # | Repo | Title | Author | URL |

Always include clickable GitHub URLs.

### Contextual Actions (Dynamic)

Use `AskUserQuestion`: "Which PR to act on?" with PR numbers + "Done".

When user picks a PR:
1. Fetch state: `gh pr view <URL> --json state,reviewDecision,statusCheckRollup,isDraft,mergeable`
2. Build dynamic options from state:
   - Approved + passing + mergeable → "Merge", "Squash and merge"
   - Checks failing → "View failing checks", "Re-run checks"
   - No reviews → "Request review from..."
   - Draft → "Mark ready for review"
   - Changes requested → "View review comments"
   - Always: "Add a comment", "Open in browser", "Done"
3. Execute with confirmation. Action loop until done.

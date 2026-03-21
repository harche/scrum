Fetch GitHub activity for a specific team member.

Arguments: $ARGUMENTS
Format: `<name-or-partial>`
Example: `/team-member-github Sai` or `/team-member-github Aditi`

Look up the GitHub handle by matching the name argument (case-insensitive partial match) against roster keys. Search both `config/team-roster-dra.json` and `config/team-roster-core.json` (no team selection needed — search all rosters). If no match is found, ask the user for the GitHub handle.

## Steps

1. **Determine time window:**
   Find the active sprint (try both "Node Core" and "Node Devices" patterns):
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprints active`
   Use the sprint startDate as the `since-date` for GitHub queries. If no sprint found, default to 14 days ago.

2. **GitHub PRs (authored):**
   ```
   gh search prs --author=<github-handle> --updated=">=$since-date" --sort=updated --limit=20 --json repository,title,state,url,updatedAt,createdAt
   ```
   For each PR, note: repo, title, state, created/updated dates.

3. **GitHub PR reviews:**
   ```
   gh search prs --reviewed-by=<github-handle> --updated=">=$since-date" --sort=updated --limit=20 --json repository,title,state,url,author
   ```

4. **GitHub issues:**
   ```
   gh search issues --author=<github-handle> --updated=">=$since-date" --sort=updated --limit=10 --json repository,title,state,url
   gh search issues --commenter=<github-handle> --updated=">=$since-date" --sort=updated --limit=10 --json repository,title,state,url,author
   ```

Steps 2, 3, 4 are independent — run them **in parallel**.

## Output

### GitHub Activity — [Person Name] (@[handle])
Sprint window: [start] to [end]

### PRs Authored

Table with: #, repo, title, state, created, updated
Group by: open vs merged vs closed

### PR Reviews

Table with: #, repo, PR title, author

### GitHub Issues

Table with: #, repo, title, their role (author/commenter)

### Summary
- 1–2 sentence narrative of what they're working on in GitHub
- Areas of focus (repos, themes)
- Any PRs that appear stalled (open with no recent updates)

Always include clickable GitHub URLs.

### Actions
After presenting the report, use `AskUserQuestion` to ask: "Any actions?" with options:
- Post to GitHub Discussion
- No actions needed

## Posting to GitHub Discussion (Optional)

When the user opts to post, add the report as a **comment** on an existing Discussion. Use `AskUserQuestion` to ask for the discussion number if not known.

1. **Build the report body** — write the full output (PRs, reviews, issues, summary) as markdown to a temp file.

2. **Post:** `bin/gh-discussion.sh comment <discussion-number> <body-file>`
   Show the returned comment URL to the user.

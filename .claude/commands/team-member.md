Show a comprehensive activity summary for a team member during the current sprint.

Arguments: $ARGUMENTS
Format: `<name-or-partial>`
Example: `/team-member Sai` or `/team-member Aditi`

Look up the GitHub handle by matching the name argument (case-insensitive partial match) against roster keys. Search both `config/team-roster-dra.json` and `config/team-roster-core.json` (no team selection needed — search all rosters). If no match is found, ask the user for the GitHub handle.

## Steps

1. **Identify the person in Jira:**
   Find the active Node Core sprint:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprints active` — filter for "Node Core".

   Get sprint issues and match the name argument (case-insensitive partial match) against assignee displayName:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprint-issues <sprintId>`

   Note the sprint startDate and endDate for time-bounding queries.

2. **Their sprint items:**
   From the sprint issues, filter to items assigned to this person. Show status, summary, story points.

3. **Their Jira activity (comments):**
   For each of their assigned items, fetch comments:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh comments <ISSUE-KEY>`
   Show recent comments by this person (within sprint dates). Convert ADF body to readable text. Also note comments from others on their items (review feedback, questions).

4. **Their broader Jira activity:**
   Search for issues they updated recently (not just sprint items):
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'assignee = "<email>" AND updated >= "<sprintStartDate>" ORDER BY updated DESC'`

5. **Their GitHub PRs (authored):**
   Search for PRs created or updated during the sprint window:
   ```
   gh search prs --author=<github-handle> --updated=">=$sprintStartDate" --sort=updated --limit=20
   ```
   For each PR, note: repo, title, state, created/updated dates, review status.

6. **Their GitHub PR reviews:**
   Search for PRs they reviewed:
   ```
   gh search prs --reviewed-by=<github-handle> --updated=">=$sprintStartDate" --sort=updated --limit=20
   ```

7. **Their GitHub issues:**
   Search for issues they commented on or authored:
   ```
   gh search issues --author=<github-handle> --updated=">=$sprintStartDate" --sort=updated --limit=10
   gh search issues --commenter=<github-handle> --updated=">=$sprintStartDate" --sort=updated --limit=10
   ```

## ADF Handling
API v3 returns comment `body` in Atlassian Document Format (ADF). Extract readable text by recursively walking ADF nodes: collect `text` from `type: "text"` nodes, add newlines after `paragraph`, `heading`, `listItem`, `blockquote`, and `hardBreak` nodes.

## Output

### Activity Summary — [Person Name]
Sprint: [name], GitHub: @[handle]

### Sprint Items

Table with: #, key, type, summary, status, story points

### Jira Activity
- Recent comments they wrote (date, issue, snippet)
- Items they updated outside the sprint board

### GitHub PRs (Authored)

Table with: #, repo, title, state, created, reviews status
Group by: open vs merged vs closed

### GitHub Reviews

Table with: #, repo, PR title, author, their review status (approved/changes requested/commented)

### GitHub Issues

Table with: #, repo, title, their role (author/commenter)

### Overall Assessment
- What they're primarily working on this sprint
- Where they're active (Jira vs upstream vs CI)
- Any items that appear stalled (no recent activity)
- Conversation threads that may need follow-up

Always include clickable Jira URLs and GitHub URLs.

### Actions
After presenting the report, use `AskUserQuestion` to ask: "Any actions for [Person Name]?" with options:
- Post to GitHub Discussion
- No actions needed

## Posting to GitHub Discussion (Optional)

When the user opts to post, add the report as a **comment** on an existing Discussion (e.g., the standup discussion for this sprint). Use `AskUserQuestion` to ask for the discussion number if not already known (e.g., "Which discussion number to post to? (e.g., 3)").

1. **Build the report body** — write the full output (sprint items, Jira activity, GitHub PRs, reviews, issues, overall assessment) as markdown to a temp file.

2. **Post:** `bin/gh-discussion.sh comment <discussion-number> <body-file>`
   Show the returned comment URL to the user.

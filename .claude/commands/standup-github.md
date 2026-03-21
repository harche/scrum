Fetch GitHub activity for all team members for the standup.

## Steps

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team's sprint filter and roster file for all subsequent steps.

2. Find the active sprint for the selected team:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprints active` — filter for the team's sprint name pattern.
   Note the sprint startDate for time-bounding GitHub queries (use 7 days ago or sprint start, whichever is more recent).

3. Load the **team roster** from the selected team's roster file.

4. Launch background subagents (grouped ~4 members per subagent) to fetch GitHub activity concurrently.

Each subagent handles ~4 roster members. For each member:

a. **GitHub PRs authored:**
   `gh search prs --author=<github-handle> --updated=">=<since-date>" --sort=updated --limit=10 --json repository,title,state,url,updatedAt,createdAt`

b. **GitHub PR reviews:**
   `gh search prs --reviewed-by=<github-handle> --updated=">=<since-date>" --sort=updated --limit=10 --json repository,title,state,url,author`

c. **GitHub PR/issue comments:**
   `gh search prs --commenter=<github-handle> --updated=">=<since-date>" --sort=updated --limit=10 --json repository,title,state,url,author`

Calls a, b, c are independent per member — run them in parallel within each subagent.

Each subagent must **synthesize** the raw data into a brief narrative summary per member (see Output). Do NOT return raw PR tables — return a 1–2 sentence summary.

## Output

### Team GitHub Activity (Last 7 Days)

Show a **unified table** of ALL roster members with a synthesized GitHub narrative.

| # | Member | Activity Summary |
|---|--------|-----------------|

For each member:
- **Activity Summary:** A 1–2 sentence narrative synthesizing GitHub activity. Examples:
  - "3 DAS release PRs merged on instaslice-fbc, 2 DRA e2e test PRs open on origin/release — directly advancing sprint goals."
  - "Heavy upstream review week: 10 K8s PRs reviewed (ulimit, user namespaces, streaming CRI, P2P distribution)."
  - "Working on CRI-O CI fixes (libpathrs, container parallel stop test), system-reserved-compressible MCO PR merged. Reviewed asahay19's TLS PR."
  - "No visible GitHub activity this week — may be OOO or focused on non-GitHub work."

**Guidelines for good narrative summaries:**
- Lead with what they shipped (merged PRs) or what's in flight
- Name the repos/areas to give context (not just counts)
- Keep it to 1–2 sentences max — this is a standup, not a performance review
- Members with zero GitHub activity: "No visible GitHub activity this week"

### Actions
Use `AskUserQuestion` to ask: "Any actions?" with options:
- Drill into a specific member's GitHub activity
- Publish to GitHub Discussions (append to existing standup discussion)
- No actions needed

Always include clickable GitHub URLs where relevant.

## Publishing to GitHub Discussions (Optional)

When the user opts to publish, use `bin/gh-discussion.sh`:

1. **Fetch full PR tables** for all roster members using subagents in parallel (group ~4 members per subagent). Each subagent calls `bin/gh-discussion.sh fetch-prs <handle> <since-date>` for its members and returns the markdown output.

2. **Build the report body** — write to a temp file with the team GitHub activity table PLUS a "Detailed Member Activity" section at the bottom. Each member gets a collapsible `<details>` block (collapsed by default) containing PR tables from step 1 (authored, reviewed, commented).

3. **Post:** `bin/gh-discussion.sh comment <discussion-number> <body-file>`
   Use `AskUserQuestion` to ask for the discussion number if not known.
   Show the returned comment URL to the user.

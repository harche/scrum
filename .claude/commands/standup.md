Prepare a summary for the weekly standup/grooming meeting.

This command uses a **two-phase approach** so the standup can begin immediately:
- **Phase 1 (immediate):** Sprint board — show it right away so discussion can start.
- **Phase 2 (background):** Team activity enrichment — Jira comments + GitHub activity fetched in background, appended when ready.

## Phase 1 — Sprint Board (show immediately)

Run steps 1–6 (team selection + sprint discovery + 3 parallel Jira queries), then **display the Sprint Board output immediately** before moving to Phase 2.

1. **Team Selection:** Use `AskUserQuestion` to ask which team (see "Team Selection" in CLAUDE.md). Use the selected team's sprint filter, roster file, and bug components for all subsequent steps.

2. Find the active sprint for the selected team:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprints active` — filter for the team's sprint name pattern.
   Note the sprint startDate and endDate for progress calculation.

3. Load the **team roster** from the selected team's roster file.

4. Run these 3 queries **in parallel:**

   a. Get all sprint issues:
      `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh sprint-issues <sprintId>`

   b. Find recently updated items (last 7 days):
      `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'sprint = <sprintId> AND updated >= -7d ORDER BY updated DESC'`

   c. Check for new bugs filed against the selected team's components in the last 7 days (use bug components from Team Selection table in CLAUDE.md):
      `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh search 'project = OCPBUGS AND component in (<team bug components>) AND created >= -7d ORDER BY created DESC'`

5. **Display the Phase 1 output** (see Output § Phase 1 below).

6. After displaying Phase 1, use `AskUserQuestion` to ask: "Want to discuss any sprint items while team activity loads?" with options:
   - "Investigate an item" (then ask which #)
   - "Continue — wait for team activity"
   - "Skip team activity — go to actions"

   This keeps the standup interactive while background work completes.

## Phase 2 — Team Activity (background)

**Launch immediately after displaying Phase 1** — do NOT wait for the user's Phase 1 interaction.

Launch background subagents (grouped ~4 members per subagent) to fetch both Jira comments and GitHub activity concurrently:

Each subagent handles ~4 roster members. For each member:

a. **Jira comments:** For each sprint issue assigned to this member, run:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh comments <ISSUE-KEY>`
   Filter to last 7 days. Extract readable text from ADF body (recursively walk nodes, collect `text` from `type: "text"` nodes, add newlines after `paragraph`, `heading`, `listItem`, `blockquote`, `hardBreak` nodes).

b. **GitHub PRs authored:**
   `gh search prs --author=<github-handle> --updated=">=<7-days-ago-date>" --sort=updated --limit=10 --json repository,title,state,url,updatedAt,createdAt`

c. **GitHub PR reviews:**
   `gh search prs --reviewed-by=<github-handle> --updated=">=<7-days-ago-date>" --sort=updated --limit=10 --json repository,title,state,url,author`

d. **GitHub PR/issue comments:**
   `gh search prs --commenter=<github-handle> --updated=">=<7-days-ago-date>" --sort=updated --limit=10 --json repository,title,state,url,author`

Calls b, c, d are independent per member — run them in parallel within each subagent.

Each subagent must **synthesize** the raw data into a brief narrative summary per member (see Output § Phase 2). Do NOT return raw PR tables — return a 1–2 sentence summary.

When background subagents complete, **display the Phase 2 output** (Team Activity table).

## Output

### Phase 1 — Sprint Board

Display this immediately. It contains everything needed to start the standup discussion.

#### Sprint Progress
- Sprint name, days elapsed / total days, items done / total, points completed / total

#### Sprint Items
Full table of all sprint issues, grouped by status:

| # | Key | Summary | Status | Assignee | Pts |
|---|-----|---------|--------|----------|-----|

Group order: Closed/Done first, then Code Review, then In Progress, then other statuses.

#### Blockers & Risks
- Items with Blocked field set
- Bugs with priority Blocker or Critical
- Items at risk of not completing (considering days remaining)

#### New Bugs (Last 7 Days)
Any new bugs filed this week against Devices-related components. "None" if empty.

#### Discussion Topics
- Items needing grooming (no story points, no assignee)
- Items that may need to be descoped or carried over (still In Progress with sprint ending soon)

### Phase 2 — Team Activity (Last 7 Days)

Display this when background subagents complete. Announce: "Team activity is ready."

Show a **unified table** of ALL roster members combining Jira sprint status AND a synthesized GitHub narrative.

| # | Member | Sprint Items | Activity Summary |
|---|--------|-------------|-----------------|

For each member:
- **Sprint Items:** count by status (e.g., "2 Done, 1 In Progress") or "—" if none
- **Activity Summary:** A 1–2 sentence narrative synthesizing BOTH Jira comments and GitHub activity. Examples:
  - "3 DAS release PRs merged on instaslice-fbc, 2 DRA e2e test PRs open on origin/release — directly advancing sprint goals. 2 Jira comments this week."
  - "Heavy upstream review week: 10 K8s PRs reviewed (ulimit, user namespaces, streaming CRI, P2P distribution). No sprint items."
  - "Working on CRI-O CI fixes (libpathrs, container parallel stop test), system-reserved-compressible MCO PR merged. Reviewed asahay19's TLS PR."
  - "No visible Jira or GitHub activity this week — may be OOO."

**Guidelines for good narrative summaries:**
- Lead with what they shipped (merged PRs) or what's in flight
- Name the repos/areas to give context (not just counts)
- For sprint members, explicitly connect GitHub work to sprint items
- For non-sprint members, describe the upstream/downstream themes
- Keep it to 1–2 sentences max — this is a standup, not a performance review
- Include Jira comment count if any (e.g., "2 Jira comments this week")
- Members with zero activity across both Jira and GitHub: "No visible activity this week"

### Actions (after Phase 2 completes, or if user skipped to actions)

Use `AskUserQuestion` to ask: "Any actions?" with options:
- Publish to GitHub Discussions
- Flag an item as blocked
- Reassign an item
- No actions needed

If the user selects **"Publish to GitHub Discussions"**, follow the Publishing section below.

Always include clickable Jira URLs and GitHub URLs.

## Publishing to GitHub Discussions (Optional)

When the user opts to publish, use `bin/gh-discussion.sh` to build and post the report:

1. **Fetch full PR tables** for all roster members using subagents in parallel (group ~4 members per subagent). Each subagent calls `bin/gh-discussion.sh fetch-prs <handle> <since-date>` for its members and returns the markdown output.

2. **Build the enhanced report body** — write to a temp file the full standup report PLUS a "Detailed Member Activity" section at the bottom. Each member gets a collapsible `<details>` block (collapsed by default) containing:
   - Sprint items (if any, with Jira links)
   - Jira comments this week (dates and summaries)
   - PR tables from step 1 (authored, reviewed, commented)

3. **Post:** `bin/gh-discussion.sh publish "Standup — YYYY-MM-DD | Sprint N Day X/Y" <body-file>`
   Show the returned discussion URL to the user.

#!/bin/bash
# Displayed at the start of each new Claude Code session
cat <<'EOF'
IMPORTANT: Display the following command list exactly as-is to the user in your first response. Do not summarize or abbreviate — show every command.

Scrum Master commands:
  /sprint-status        — Current sprint dashboard
  /standup              — Weekly standup prep (Tuesdays)
  /standup-github       — GitHub activity for all team members
  /sprint-plan          — Sprint planning preparation
  /sprint-review        — Sprint review summary
  /bug-triage           — Bug triage session
  /carryovers           — Carryover analysis
  /team-load            — Workload distribution
  /team-member          — Individual Jira activity summary
  /team-member-github   — Individual GitHub activity summary
  /investigate          — Deep dive on a single issue
  /release-check        — Release readiness check

Team Member commands:
  /my-board             — My assigned sprint items by status
  /my-bugs              — My bugs by severity, age, customer impact
  /my-epics             — Epic progress I'm contributing to
  /my-standup           — Personal standup talking points
  /my-prs               — My open PRs + review requests for me
  /my-github-issues     — My GitHub issues (authored, assigned, commented)
  /review-queue         — PRs awaiting my review, prioritized
  /pickup               — Find unassigned work to grab
  /update <KEY>         — Comment, transition, or set points on an issue
  /blocker <KEY>        — Flag/unflag a blocker on an issue
  /briefing <KEY>       — Get up to speed on an issue fast
  /handoff <KEY>        — Prepare a handoff summary for transfer
EOF

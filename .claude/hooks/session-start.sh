#!/bin/bash
# Displayed at the start of each new Claude Code session
cat <<'EOF'
IMPORTANT: Display the following command list exactly as-is to the user in your first response. Do not summarize or abbreviate — show every command.

Available scrum commands:
  /sprint-status   — Current sprint dashboard
  /standup         — Weekly standup prep (Tuesdays)
  /sprint-plan     — Sprint planning preparation
  /sprint-review   — Sprint review summary
  /bug-triage      — Bug triage session
  /carryovers      — Carryover analysis
  /team-load       — Workload distribution
  /team-member     — Individual activity summary
  /investigate     — Deep dive on a single issue
  /release-check   — Release readiness check
EOF

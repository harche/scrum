#!/bin/bash
# GitHub activity helper — composite commands for PR/issue data
# Uses GraphQL via `gh api graphql` for efficient batching. All output is JSON.
#
# Call savings vs REST:
#   my-prs:       3 REST → 1 GraphQL
#   my-issues:    3 REST → 1 GraphQL
#   review-queue: 2 REST → 1 GraphQL
#   member-prs:   3 REST → 1 GraphQL
#   team-prs:     N×3 REST → ceil(N/6) GraphQL
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Helpers ────────────────────────────────────────────────────────────────────

_date_days_ago() {
  local days="${1:-7}"
  date -v-${days}d +%Y-%m-%d 2>/dev/null || date -d "${days} days ago" +%Y-%m-%d 2>/dev/null
}

# ── my-prs <github-handle> ────────────────────────────────────────────────────
# Authored PRs, review requests for me, recently merged
# 1 GraphQL call (was 3 REST)
cmd_my_prs() {
  local handle="${1:?GitHub handle required}"
  local since
  since=$(_date_days_ago 7)

  python3 - "$handle" "$since" <<'PYEOF'
import json, subprocess, sys

handle, since = sys.argv[1], sys.argv[2]

PR = """... on PullRequest {
  title url state createdAt updatedAt closedAt isDraft
  repository { nameWithOwner }
  author { login }
}"""

query = """{
  authoredOpen: search(query: "author:%s is:pr is:open sort:updated", type: ISSUE, first: 30) {
    nodes { %s }
  }
  authoredMerged: search(query: "author:%s is:pr is:merged merged:>=%s sort:updated", type: ISSUE, first: 10) {
    nodes { %s }
  }
  reviewRequested: search(query: "review-requested:%s is:pr is:open sort:updated", type: ISSUE, first: 20) {
    nodes { %s }
  }
}""" % (handle, PR, handle, since, PR, handle, PR)

proc = subprocess.run(['gh', 'api', 'graphql', '-f', f'query={query}'],
                      capture_output=True, text=True)
if proc.returncode != 0:
    print(json.dumps({'authoredOpen': [], 'authoredMerged': [], 'reviewRequested': [],
                      'summary': {'openPRs': 0, 'recentlyMerged': 0, 'reviewRequests': 0},
                      'error': proc.stderr.strip()}))
    sys.exit(0)

data = json.loads(proc.stdout).get('data', {})

def fmt(nodes):
    return [{'repo': p.get('repository', {}).get('nameWithOwner', ''),
             'title': p.get('title', ''),
             'state': p.get('state', '').lower(),
             'url': p.get('url', ''),
             'author': (p.get('author') or {}).get('login', ''),
             'createdAt': p.get('createdAt', ''),
             'updatedAt': p.get('updatedAt', ''),
             'closedAt': p.get('closedAt', ''),
             'isDraft': p.get('isDraft', False)} for p in nodes]

ao = data.get('authoredOpen', {}).get('nodes', [])
am = data.get('authoredMerged', {}).get('nodes', [])
rr = data.get('reviewRequested', {}).get('nodes', [])

print(json.dumps({
    'authoredOpen': fmt(ao),
    'authoredMerged': fmt(am),
    'reviewRequested': fmt(rr),
    'summary': {'openPRs': len(ao), 'recentlyMerged': len(am), 'reviewRequests': len(rr)},
}))
PYEOF
}

# ── my-issues <github-handle> ─────────────────────────────────────────────────
# Issues authored, assigned, recently commented
# 1 GraphQL call (was 3 REST)
cmd_my_issues() {
  local handle="${1:?GitHub handle required}"
  local since
  since=$(_date_days_ago 14)

  python3 - "$handle" "$since" <<'PYEOF'
import json, subprocess, sys

handle, since = sys.argv[1], sys.argv[2]

ISS = """... on Issue {
  title url state createdAt updatedAt
  repository { nameWithOwner }
  author { login }
  labels(first: 10) { nodes { name } }
}"""

query = """{
  authored: search(query: "author:%s is:issue is:open sort:updated", type: ISSUE, first: 20) {
    nodes { %s }
  }
  assigned: search(query: "assignee:%s is:issue is:open sort:updated", type: ISSUE, first: 20) {
    nodes { %s }
  }
  commented: search(query: "commenter:%s is:issue is:open updated:>=%s sort:updated", type: ISSUE, first: 20) {
    nodes { %s }
  }
}""" % (handle, ISS, handle, ISS, handle, since, ISS)

proc = subprocess.run(['gh', 'api', 'graphql', '-f', f'query={query}'],
                      capture_output=True, text=True)
if proc.returncode != 0:
    print(json.dumps({'authored': [], 'assigned': [], 'commented': [],
                      'summary': {'authored': 0, 'assigned': 0, 'commented': 0},
                      'error': proc.stderr.strip()}))
    sys.exit(0)

data = json.loads(proc.stdout).get('data', {})

def fmt(issues):
    return [{'repo': i.get('repository', {}).get('nameWithOwner', ''),
             'title': i.get('title', ''),
             'state': i.get('state', '').lower(),
             'url': i.get('url', ''),
             'author': (i.get('author') or {}).get('login', ''),
             'createdAt': i.get('createdAt', ''),
             'updatedAt': i.get('updatedAt', ''),
             'labels': [l.get('name', '') for l in i.get('labels', {}).get('nodes', [])]}
            for i in issues]

authored = data.get('authored', {}).get('nodes', [])
assigned = data.get('assigned', {}).get('nodes', [])
commented = data.get('commented', {}).get('nodes', [])

print(json.dumps({
    'authored': fmt(authored),
    'assigned': fmt(assigned),
    'commented': fmt(commented),
    'summary': {'authored': len(authored), 'assigned': len(assigned), 'commented': len(commented)},
}))
PYEOF
}

# ── review-queue <github-handle> ──────────────────────────────────────────────
# PRs awaiting my review, prioritized by age
# 1 GraphQL call (was 2 REST)
cmd_review_queue() {
  local handle="${1:?GitHub handle required}"

  python3 - "$handle" <<'PYEOF'
import json, subprocess, sys
from datetime import datetime, timezone

handle = sys.argv[1]

PR = """... on PullRequest {
  title url state createdAt updatedAt isDraft
  repository { nameWithOwner }
  author { login }
}"""

query = """{
  reviewRequested: search(query: "review-requested:%s is:pr is:open sort:created", type: ISSUE, first: 30) {
    nodes { %s }
  }
  mentioned: search(query: "mentions:%s is:pr is:open sort:updated", type: ISSUE, first: 10) {
    nodes { %s }
  }
}""" % (handle, PR, handle, PR)

proc = subprocess.run(['gh', 'api', 'graphql', '-f', f'query={query}'],
                      capture_output=True, text=True)
if proc.returncode != 0:
    print(json.dumps({'reviewRequested': [], 'mentioned': [],
                      'summary': {'reviewRequested': 0, 'mentioned': 0},
                      'error': proc.stderr.strip()}))
    sys.exit(0)

data = json.loads(proc.stdout).get('data', {})
now = datetime.now(timezone.utc)

def fmt(prs):
    result = []
    for p in prs:
        created = p.get('createdAt', '')
        age_days = 0
        try:
            dt = datetime.fromisoformat(created.replace('Z', '+00:00'))
            age_days = (now - dt).days
        except Exception:
            pass
        result.append({
            'repo': p.get('repository', {}).get('nameWithOwner', ''),
            'title': p.get('title', ''),
            'url': p.get('url', ''),
            'author': (p.get('author') or {}).get('login', ''),
            'createdAt': created,
            'ageDays': age_days,
            'isDraft': p.get('isDraft', False),
        })
    return sorted(result, key=lambda x: -x['ageDays'])

requested = data.get('reviewRequested', {}).get('nodes', [])
mentions = data.get('mentioned', {}).get('nodes', [])

print(json.dumps({
    'reviewRequested': fmt(requested),
    'mentioned': fmt(mentions),
    'summary': {'reviewRequested': len(requested), 'mentioned': len(mentions)},
}))
PYEOF
}

# ── team-prs <roster-file> ────────────────────────────────────────────────────
# GitHub activity for all team members (for standup-github)
# ceil(N/6) GraphQL calls (was N×3 REST — e.g. 27 for DRA, 48 for Core)
cmd_team_prs() {
  local roster_file="${1:?Roster file required}"

  if [[ ! -f "$roster_file" ]]; then
    echo "{\"error\":\"Roster file not found: ${roster_file}\"}" >&2
    return 1
  fi

  local since
  since=$(_date_days_ago 7)

  python3 - "$roster_file" "$since" <<'PYEOF'
import json, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

roster_file, since = sys.argv[1], sys.argv[2]

with open(roster_file) as f:
    roster = json.load(f)
members = [(name, handle) for name, handle in roster.get('members', {}).items() if handle]

if not members:
    print(json.dumps({'members': [], 'summary': {'totalMembers': 0}}))
    sys.exit(0)

PR = """... on PullRequest {
  title url state
  repository { nameWithOwner }
  author { login }
  createdAt closedAt
}"""

def build_batch_query(batch, since):
    """Build a single GraphQL query covering multiple members."""
    parts = []
    for idx, (name, handle) in enumerate(batch):
        alias = f'm{idx}'
        parts.append(f"""
  {alias}_authored: search(query: "author:{handle} is:pr updated:>={since} sort:updated", type: ISSUE, first: 10) {{
    nodes {{ {PR} }}
  }}
  {alias}_reviewed: search(query: "reviewed-by:{handle} is:pr updated:>={since} sort:updated", type: ISSUE, first: 10) {{
    nodes {{ {PR} }}
  }}
  {alias}_commented: search(query: "commenter:{handle} is:pr updated:>={since} sort:updated", type: ISSUE, first: 5) {{
    nodes {{ {PR} }}
  }}""")
    return '{' + ''.join(parts) + '\n}'

def run_batch(query):
    """Execute a single batched GraphQL query."""
    proc = subprocess.run(['gh', 'api', 'graphql', '-f', f'query={query}'],
                          capture_output=True, text=True)
    if proc.returncode != 0:
        return {}
    return json.loads(proc.stdout).get('data', {})

# Batch members into groups of 6 (18 search aliases per query)
batch_size = 6
batches = [members[i:i+batch_size] for i in range(0, len(members), batch_size)]
queries = [build_batch_query(batch, since) for batch in batches]

# Run batches in parallel
with ThreadPoolExecutor(max_workers=len(queries)) as executor:
    results = list(executor.map(run_batch, queries))

# Parse results
all_members = []
for batch_idx, batch in enumerate(batches):
    data = results[batch_idx]
    for idx, (name, handle) in enumerate(batch):
        alias = f'm{idx}'
        authored = data.get(f'{alias}_authored', {}).get('nodes', [])
        reviewed = data.get(f'{alias}_reviewed', {}).get('nodes', [])
        commented = data.get(f'{alias}_commented', {}).get('nodes', [])
        all_members.append({
            'name': name,
            'github': handle,
            'authored': len(authored),
            'reviewed': len(reviewed),
            'commented': len(commented),
            'prs': [{'repo': p.get('repository', {}).get('nameWithOwner', ''),
                     'title': p.get('title', ''),
                     'state': p.get('state', '').lower(),
                     'url': p.get('url', '')} for p in authored[:5]],
        })

all_members.sort(key=lambda m: m.get('authored', 0) + m.get('reviewed', 0), reverse=True)
print(json.dumps({'members': all_members, 'summary': {'totalMembers': len(all_members)}}))
PYEOF
}

# ── member-prs <github-handle> ────────────────────────────────────────────────
# Individual member's GitHub activity
# 1 GraphQL call (was 3 REST)
cmd_member_prs() {
  local handle="${1:?GitHub handle required}"
  local since
  since=$(_date_days_ago 7)

  python3 - "$handle" "$since" <<'PYEOF'
import json, subprocess, sys

handle, since = sys.argv[1], sys.argv[2]

PR = """... on PullRequest {
  title url state createdAt updatedAt closedAt isDraft
  repository { nameWithOwner }
  author { login }
}"""

ISS = """... on Issue {
  title url state createdAt updatedAt
  repository { nameWithOwner }
}"""

query = """{
  authored: search(query: "author:%s is:pr updated:>=%s sort:updated", type: ISSUE, first: 20) {
    nodes { %s }
  }
  reviewed: search(query: "reviewed-by:%s is:pr updated:>=%s sort:updated", type: ISSUE, first: 20) {
    nodes { %s }
  }
  issues: search(query: "author:%s is:issue updated:>=%s sort:updated", type: ISSUE, first: 10) {
    nodes { %s }
  }
}""" % (handle, since, PR, handle, since, PR, handle, since, ISS)

proc = subprocess.run(['gh', 'api', 'graphql', '-f', f'query={query}'],
                      capture_output=True, text=True)
if proc.returncode != 0:
    print(json.dumps({'authored': [], 'reviewed': [], 'issues': [],
                      'summary': {'authored': 0, 'reviewed': 0, 'issues': 0},
                      'error': proc.stderr.strip()}))
    sys.exit(0)

data = json.loads(proc.stdout).get('data', {})

def fmt_prs(prs):
    return [{'repo': p.get('repository', {}).get('nameWithOwner', ''),
             'title': p.get('title', ''),
             'state': p.get('state', '').lower(),
             'url': p.get('url', ''),
             'author': (p.get('author') or {}).get('login', ''),
             'createdAt': p.get('createdAt', ''),
             'closedAt': p.get('closedAt', ''),
             'isDraft': p.get('isDraft', False)} for p in prs]

def fmt_issues(iss):
    return [{'repo': i.get('repository', {}).get('nameWithOwner', ''),
             'title': i.get('title', ''),
             'state': i.get('state', '').lower(),
             'url': i.get('url', '')} for i in iss]

authored = data.get('authored', {}).get('nodes', [])
reviewed = data.get('reviewed', {}).get('nodes', [])
issues = data.get('issues', {}).get('nodes', [])

print(json.dumps({
    'authored': fmt_prs(authored),
    'reviewed': fmt_prs(reviewed),
    'issues': fmt_issues(issues),
    'summary': {'authored': len(authored), 'reviewed': len(reviewed), 'issues': len(issues)},
}))
PYEOF
}

# ── Help ───────────────────────────────────────────────────────────────────────

cmd_help() {
  cat <<'EOF'
Usage: gh-activity.sh <command> [args]

Commands:
  my-prs <handle>           My open PRs + review requests + recently merged
  my-issues <handle>        My GitHub issues (authored, assigned, commented)
  review-queue <handle>     PRs awaiting my review, prioritized by age
  team-prs <roster-file>    GitHub activity for all roster members
  member-prs <handle>       Individual member's GitHub activity

All output is JSON. Uses GraphQL for efficient batching. Requires the `gh` CLI (authenticated).
EOF
}

# ── Dispatch ───────────────────────────────────────────────────────────────────

case "${1:-help}" in
  my-prs)        cmd_my_prs "${2:?GitHub handle required}" ;;
  my-issues)     cmd_my_issues "${2:?GitHub handle required}" ;;
  review-queue)  cmd_review_queue "${2:?GitHub handle required}" ;;
  team-prs)      cmd_team_prs "${2:?Roster file required}" ;;
  member-prs)    cmd_member_prs "${2:?GitHub handle required}" ;;
  help|--help|-h) cmd_help ;;
  *)             echo "Unknown command: $1" >&2; cmd_help >&2; exit 1 ;;
esac

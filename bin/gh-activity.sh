#!/bin/bash
# GitHub activity helper — composite commands for PR/issue data
# Uses the `gh` CLI. All output is JSON.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Helpers ────────────────────────────────────────────────────────────────────

_gh_search_prs() {
  gh search prs "$@" --json repository,title,state,url,author,createdAt,updatedAt,isDraft 2>/dev/null || echo '[]'
}

_gh_search_issues() {
  gh search issues "$@" --json repository,title,state,url,author,createdAt,updatedAt,labels 2>/dev/null || echo '[]'
}

# ── my-prs <github-handle> ────────────────────────────────────────────────────
# Authored PRs, review requests for me, recently merged
cmd_my_prs() {
  local handle="${1:?GitHub handle required}"
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" RETURN

  # Parallel: authored open + authored merged + review-requested
  (gh search prs --author="$handle" --state=open --sort=updated --limit=30 \
    --json repository,title,state,url,author,createdAt,updatedAt,isDraft 2>/dev/null || echo '[]') > "$tmpdir/authored_open.json" &

  (gh search prs --author="$handle" --state=merged --sort=updated --limit=10 --merged=">=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d 2>/dev/null)" \
    --json repository,title,state,url,createdAt,closedAt 2>/dev/null || echo '[]') > "$tmpdir/authored_merged.json" &

  (gh search prs --review-requested="$handle" --state=open --sort=updated --limit=20 \
    --json repository,title,state,url,author,createdAt,updatedAt 2>/dev/null || echo '[]') > "$tmpdir/review_requested.json" &

  wait

  python3 -c "
import json
with open('$tmpdir/authored_open.json') as f: authored_open = json.load(f)
with open('$tmpdir/authored_merged.json') as f: authored_merged = json.load(f)
with open('$tmpdir/review_requested.json') as f: review_requested = json.load(f)

def fmt(prs):
    return [{'repo': p.get('repository',{}).get('nameWithOwner',''), 'title': p.get('title',''),
             'state': p.get('state',''), 'url': p.get('url',''),
             'author': p.get('author',{}).get('login',''),
             'createdAt': p.get('createdAt',''), 'updatedAt': p.get('updatedAt',''),
             'closedAt': p.get('closedAt',''),
             'isDraft': p.get('isDraft', False)} for p in prs]

result = {
    'authoredOpen': fmt(authored_open),
    'authoredMerged': fmt(authored_merged),
    'reviewRequested': fmt(review_requested),
    'summary': {
        'openPRs': len(authored_open),
        'recentlyMerged': len(authored_merged),
        'reviewRequests': len(review_requested),
    },
}
print(json.dumps(result))
"
}

# ── my-issues <github-handle> ─────────────────────────────────────────────────
# Issues authored, assigned, recently commented
cmd_my_issues() {
  local handle="${1:?GitHub handle required}"
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" RETURN

  (gh search issues --author="$handle" --state=open --sort=updated --limit=20 \
    --json repository,title,state,url,createdAt,updatedAt,labels 2>/dev/null || echo '[]') > "$tmpdir/authored.json" &

  (gh search issues --assignee="$handle" --state=open --sort=updated --limit=20 \
    --json repository,title,state,url,author,createdAt,updatedAt,labels 2>/dev/null || echo '[]') > "$tmpdir/assigned.json" &

  (gh search issues --commenter="$handle" --state=open --sort=updated --limit=20 --updated=">=$(date -v-14d +%Y-%m-%d 2>/dev/null || date -d '14 days ago' +%Y-%m-%d 2>/dev/null)" \
    --json repository,title,state,url,author,createdAt,updatedAt 2>/dev/null || echo '[]') > "$tmpdir/commented.json" &

  wait

  python3 -c "
import json
with open('$tmpdir/authored.json') as f: authored = json.load(f)
with open('$tmpdir/assigned.json') as f: assigned = json.load(f)
with open('$tmpdir/commented.json') as f: commented = json.load(f)

def fmt(issues):
    return [{'repo': i.get('repository',{}).get('nameWithOwner',''), 'title': i.get('title',''),
             'state': i.get('state',''), 'url': i.get('url',''),
             'author': i.get('author',{}).get('login',''),
             'createdAt': i.get('createdAt',''), 'updatedAt': i.get('updatedAt',''),
             'labels': [l.get('name','') for l in i.get('labels',[])]} for i in issues]

# Deduplicate by URL
seen = set()
all_issues = []
for i in authored + assigned + commented:
    url = i.get('url','')
    if url not in seen:
        seen.add(url)
        all_issues.append(i)

result = {
    'authored': fmt(authored),
    'assigned': fmt(assigned),
    'commented': fmt(commented),
    'summary': {
        'authored': len(authored),
        'assigned': len(assigned),
        'commented': len(commented),
    },
}
print(json.dumps(result))
"
}

# ── review-queue <github-handle> ──────────────────────────────────────────────
# PRs awaiting my review, prioritized by age
cmd_review_queue() {
  local handle="${1:?GitHub handle required}"
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" RETURN

  (gh search prs --review-requested="$handle" --state=open --sort=created --limit=30 \
    --json repository,title,state,url,author,createdAt,updatedAt,isDraft 2>/dev/null || echo '[]') > "$tmpdir/requested.json" &

  (gh search prs --mentions="$handle" --state=open --sort=updated --limit=10 \
    --json repository,title,state,url,author,createdAt,updatedAt 2>/dev/null || echo '[]') > "$tmpdir/mentions.json" &

  wait

  python3 -c "
import json
from datetime import datetime, timezone
with open('$tmpdir/requested.json') as f: requested = json.load(f)
with open('$tmpdir/mentions.json') as f: mentions = json.load(f)
now = datetime.now(timezone.utc)

def fmt(prs):
    result = []
    for p in prs:
        created = p.get('createdAt','')
        age_days = 0
        try:
            dt = datetime.fromisoformat(created.replace('Z','+00:00'))
            age_days = (now - dt).days
        except: pass
        result.append({
            'repo': p.get('repository',{}).get('nameWithOwner',''),
            'title': p.get('title',''), 'url': p.get('url',''),
            'author': p.get('author',{}).get('login',''),
            'createdAt': created, 'ageDays': age_days,
            'isDraft': p.get('isDraft', False),
        })
    return sorted(result, key=lambda x: -x['ageDays'])

result = {
    'reviewRequested': fmt(requested),
    'mentioned': fmt(mentions),
    'summary': {'reviewRequested': len(requested), 'mentioned': len(mentions)},
}
print(json.dumps(result))
"
}

# ── team-prs <roster-file> ────────────────────────────────────────────────────
# GitHub activity for all team members (for standup-github)
cmd_team_prs() {
  local roster_file="${1:?Roster file required}"

  if [[ ! -f "$roster_file" ]]; then
    echo "{\"error\":\"Roster file not found: ${roster_file}\"}" >&2
    return 1
  fi

  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" RETURN

  local since
  since=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d 2>/dev/null)

  # Launch parallel searches for each member
  while IFS='|' read -r name handle; do
    [[ -z "$handle" ]] && continue
    (
      authored=$(gh search prs --author="$handle" --updated=">=${since}" --sort=updated --limit=10 \
        --json repository,title,state,url,createdAt,closedAt 2>/dev/null || echo '[]')
      reviewed=$(gh search prs --reviewed-by="$handle" --updated=">=${since}" --sort=updated --limit=10 \
        --json repository,title,url,author,state 2>/dev/null || echo '[]')
      commented=$(gh search prs --commenter="$handle" --updated=">=${since}" --sort=updated --limit=5 \
        --json repository,title,url,state 2>/dev/null || echo '[]')

      python3 -c "
import json, sys
name = sys.argv[1]; handle = sys.argv[2]
authored = json.loads(sys.argv[3]); reviewed = json.loads(sys.argv[4]); commented = json.loads(sys.argv[5])
result = {'name': name, 'github': handle,
  'authored': len(authored), 'reviewed': len(reviewed), 'commented': len(commented),
  'prs': [{'repo': p.get('repository',{}).get('nameWithOwner',''), 'title': p.get('title',''),
           'state': p.get('state',''), 'url': p.get('url','')} for p in authored[:5]]}
print(json.dumps(result))
" "$name" "$handle" "$authored" "$reviewed" "$commented"
    ) > "$tmpdir/${handle}.json" 2>/dev/null &
  done < <(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); [print(f'{n}|{h}') for n,h in d.get('members',{}).items()]" "$roster_file")
  wait

  # Collect all results
  python3 -c "
import json, os, sys
tmpdir = sys.argv[1]
members = []
for f in sorted(os.listdir(tmpdir)):
    if f.endswith('.json'):
        with open(os.path.join(tmpdir, f)) as fh:
            try: members.append(json.load(fh))
            except: pass
members.sort(key=lambda m: m.get('authored',0) + m.get('reviewed',0), reverse=True)
print(json.dumps({'members': members, 'summary': {'totalMembers': len(members)}}))
" "$tmpdir"
}

# ── member-prs <github-handle> ────────────────────────────────────────────────
# Individual member's GitHub activity
cmd_member_prs() {
  local handle="${1:?GitHub handle required}"
  local since
  since=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d 2>/dev/null)

  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" RETURN

  (gh search prs --author="$handle" --updated=">=${since}" --sort=updated --limit=20 \
    --json repository,title,state,url,createdAt,updatedAt,closedAt,isDraft 2>/dev/null || echo '[]') > "$tmpdir/authored.json" &

  (gh search prs --reviewed-by="$handle" --updated=">=${since}" --sort=updated --limit=20 \
    --json repository,title,url,author,state 2>/dev/null || echo '[]') > "$tmpdir/reviewed.json" &

  (gh search issues --author="$handle" --updated=">=${since}" --sort=updated --limit=10 \
    --json repository,title,state,url,createdAt,updatedAt 2>/dev/null || echo '[]') > "$tmpdir/issues.json" &

  wait

  python3 -c "
import json
with open('$tmpdir/authored.json') as f: authored = json.load(f)
with open('$tmpdir/reviewed.json') as f: reviewed = json.load(f)
with open('$tmpdir/issues.json') as f: issues = json.load(f)

def fmt_prs(prs):
    return [{'repo': p.get('repository',{}).get('nameWithOwner',''), 'title': p.get('title',''),
             'state': p.get('state',''), 'url': p.get('url',''),
             'author': p.get('author',{}).get('login',''),
             'createdAt': p.get('createdAt',''), 'closedAt': p.get('closedAt',''),
             'isDraft': p.get('isDraft', False)} for p in prs]

def fmt_issues(iss):
    return [{'repo': i.get('repository',{}).get('nameWithOwner',''), 'title': i.get('title',''),
             'state': i.get('state',''), 'url': i.get('url','')} for i in iss]

result = {
    'authored': fmt_prs(authored),
    'reviewed': fmt_prs(reviewed),
    'issues': fmt_issues(issues),
    'summary': {'authored': len(authored), 'reviewed': len(reviewed), 'issues': len(issues)},
}
print(json.dumps(result))
"
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

All output is JSON. Requires the `gh` CLI (authenticated).
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

#!/usr/bin/env bash
# GitHub Discussions helper for harche/scrum
# Usage:
#   bin/gh-discussion.sh publish <title> <body-file>
#   bin/gh-discussion.sh comment <discussion-number> <body-file>
#   bin/gh-discussion.sh fetch-prs <github-handle> <since-date>
#
# publish: Posts a Discussion to harche/scrum (General category). Prints the URL.
# comment: Adds a comment to an existing Discussion. Prints the comment URL.
# fetch-prs: Fetches authored/reviewed/commented PRs, outputs markdown tables.

set -euo pipefail

REPO_OWNER="harche"
REPO_NAME="scrum"

cmd_publish() {
  local title="$1"
  local body_file="$2"

  if [[ ! -f "$body_file" ]]; then
    echo "Error: body file not found: $body_file" >&2
    exit 1
  fi

  # Get repo ID and General category ID
  local result
  result=$(gh api graphql -f query='
    query($owner: String!, $name: String!) {
      repository(owner: $owner, name: $name) {
        id
        discussionCategories(first: 10) {
          nodes { id name }
        }
      }
    }' -f owner="$REPO_OWNER" -f name="$REPO_NAME")

  local repo_id cat_id
  repo_id=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['repository']['id'])")
  cat_id=$(echo "$result" | python3 -c "
import sys, json
cats = json.load(sys.stdin)['data']['repository']['discussionCategories']['nodes']
for c in cats:
    if c['name'] == 'General':
        print(c['id'])
        break
")

  if [[ -z "$cat_id" ]]; then
    echo "Error: 'General' discussion category not found" >&2
    exit 1
  fi

  local body
  body=$(cat "$body_file")

  local response
  response=$(gh api graphql \
    -f query='mutation($repoId: ID!, $catId: ID!, $title: String!, $body: String!) {
      createDiscussion(input: {repositoryId: $repoId, categoryId: $catId, title: $title, body: $body}) {
        discussion { url number }
      }
    }' \
    -f repoId="$repo_id" \
    -f catId="$cat_id" \
    -f title="$title" \
    -f body="$body")

  echo "$response" | python3 -c "
import sys, json
d = json.load(sys.stdin)['data']['createDiscussion']['discussion']
print(d['url'])
"
}

cmd_comment() {
  local discussion_number="$1"
  local body_file="$2"

  if [[ ! -f "$body_file" ]]; then
    echo "Error: body file not found: $body_file" >&2
    exit 1
  fi

  # Get the discussion node ID
  local disc_result
  disc_result=$(gh api graphql -f query='
    query($owner: String!, $name: String!, $number: Int!) {
      repository(owner: $owner, name: $name) {
        discussion(number: $number) { id url }
      }
    }' -f owner="$REPO_OWNER" -f name="$REPO_NAME" -F number="$discussion_number")

  local disc_id
  disc_id=$(echo "$disc_result" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['repository']['discussion']['id'])")

  local body
  body=$(cat "$body_file")

  local response
  response=$(gh api graphql \
    -f query='mutation($discId: ID!, $body: String!) {
      addDiscussionComment(input: {discussionId: $discId, body: $body}) {
        comment { url }
      }
    }' \
    -f discId="$disc_id" \
    -f body="$body")

  echo "$response" | python3 -c "
import sys, json
print(json.load(sys.stdin)['data']['addDiscussionComment']['comment']['url'])
"
}

cmd_fetch_prs() {
  local handle="$1"
  local since="$2"

  # Run all 3 queries in parallel
  local tmp_authored tmp_reviewed tmp_commented
  tmp_authored=$(mktemp)
  tmp_reviewed=$(mktemp)
  tmp_commented=$(mktemp)

  gh search prs --author="$handle" --updated=">=$since" --sort=updated --limit=10 \
    --json repository,title,state,url > "$tmp_authored" 2>/dev/null &

  gh search prs --reviewed-by="$handle" --updated=">=$since" --sort=updated --limit=10 \
    --json repository,title,state,url,author > "$tmp_reviewed" 2>/dev/null &

  gh search prs --commenter="$handle" --updated=">=$since" --sort=updated --limit=10 \
    --json repository,title,state,url,author > "$tmp_commented" 2>/dev/null &

  wait

  # Format all three tables via Python
  python3 -c "
import json, sys, re

def pr_num(url):
    return url.rstrip('/').split('/')[-1]

def fmt_authored(data):
    if not data:
        return '**Authored PRs:** None this week.\n'
    lines = ['**Authored PRs:**\n',
             '| # | Repo | Title | State | URL |',
             '|---|------|-------|-------|-----|']
    for i, pr in enumerate(data, 1):
        repo = pr['repository']['nameWithOwner']
        title = pr['title'].replace('|', r'\|')
        state = pr['state'].lower()
        if state == 'merged': state = '**Merged**'
        url = pr['url']
        num = pr_num(url)
        lines.append(f'| {i} | {repo} | {title} | {state} | [#{num}]({url}) |')
    return '\n'.join(lines) + '\n'

def fmt_reviewed(data, label='Reviewed PRs'):
    if not data:
        return f'**{label}:** None this week.\n'
    lines = [f'**{label}:**\n',
             '| # | Repo | Title | Author | URL |',
             '|---|------|-------|--------|-----|']
    for i, pr in enumerate(data, 1):
        repo = pr['repository']['nameWithOwner']
        title = pr['title'].replace('|', r'\|')
        author = pr.get('author', {}).get('login', '?') if isinstance(pr.get('author'), dict) else '?'
        url = pr['url']
        num = pr_num(url)
        lines.append(f'| {i} | {repo} | {title} | {author} | [#{num}]({url}) |')
    return '\n'.join(lines) + '\n'

with open('$tmp_authored') as f: authored = json.load(f)
with open('$tmp_reviewed') as f: reviewed = json.load(f)
with open('$tmp_commented') as f: commented = json.load(f)

print(fmt_authored(authored))
print(fmt_reviewed(reviewed, 'Reviewed PRs'))
print(fmt_reviewed(commented, 'Commented PRs'))
"

  rm -f "$tmp_authored" "$tmp_reviewed" "$tmp_commented"
}

# --- Main ---
case "${1:-}" in
  publish)
    shift
    if [[ $# -lt 2 ]]; then
      echo "Usage: $0 publish <title> <body-file>" >&2
      exit 1
    fi
    cmd_publish "$1" "$2"
    ;;
  comment)
    shift
    if [[ $# -lt 2 ]]; then
      echo "Usage: $0 comment <discussion-number> <body-file>" >&2
      exit 1
    fi
    cmd_comment "$1" "$2"
    ;;
  fetch-prs)
    shift
    if [[ $# -lt 2 ]]; then
      echo "Usage: $0 fetch-prs <github-handle> <since-date>" >&2
      exit 1
    fi
    cmd_fetch_prs "$1" "$2"
    ;;
  *)
    echo "Usage: $0 {publish|comment|fetch-prs}" >&2
    echo "  publish <title> <body-file>          Post a Discussion to harche/scrum" >&2
    echo "  comment <discussion-number> <body-file>  Add comment to existing Discussion" >&2
    echo "  fetch-prs <handle> <since-date>      Fetch PR tables for a member" >&2
    exit 1
    ;;
esac

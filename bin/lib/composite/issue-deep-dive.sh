#!/bin/bash
# Composite: issue-deep-dive <KEY>
# Full issue details + comments (ADF converted) + linked issues
# Serves: /investigate, /briefing, /handoff

[[ -n "${_COMPOSITE_ISSUE_DEEP_DIVE_LOADED:-}" ]] && return 0
_COMPOSITE_ISSUE_DEEP_DIVE_LOADED=1

cmd_issue_deep_dive() {
  local key="${1:?Issue key required (e.g., OCPNODE-1234)}"

  # ── Fetch issue + comments in parallel ───────────────────────────────────
  parallel_init
  parallel_run "issue" cmd_get "$key"
  parallel_run "comments" cmd_comments "$key"
  parallel_run "transitions" cmd_transitions "$key"
  parallel_wait_all || true

  local issue_json comments_json transitions_json
  issue_json=$(parallel_get "issue")
  comments_json=$(parallel_get "comments")
  transitions_json=$(parallel_get "transitions")

  local adf_py
  adf_py="$(cd "$(dirname "${BASH_SOURCE[0]}")/../util" && pwd)/adf.py"

  python3 - "$comments_json" "$transitions_json" "$adf_py" "$issue_json" <<'PYEOF'
import json, sys, importlib.util

comments_data = json.loads(sys.argv[1])
transitions_data = json.loads(sys.argv[2])
adf_py_path = sys.argv[3]
issue = json.loads(sys.argv[4])

# Load ADF converter
spec = importlib.util.spec_from_file_location("adf", adf_py_path)
adf_mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adf_mod)

f = issue.get("fields", {})

# Extract description
desc = f.get("description")
desc_text = adf_mod.adf_to_text(desc).strip() if isinstance(desc, dict) else (desc or "")

# Extract comments
comments = adf_mod.extract_comments(comments_data)

# Extract linked issues
linked = []
for link in f.get("issuelinks", []):
    link_type = link.get("type", {})
    if "outwardIssue" in link:
        target = link["outwardIssue"]
        linked.append({
            "key": target.get("key", ""),
            "summary": target.get("fields", {}).get("summary", ""),
            "status": target.get("fields", {}).get("status", {}).get("name", ""),
            "relationship": link_type.get("outward", ""),
        })
    if "inwardIssue" in link:
        target = link["inwardIssue"]
        linked.append({
            "key": target.get("key", ""),
            "summary": target.get("fields", {}).get("summary", ""),
            "status": target.get("fields", {}).get("status", {}).get("name", ""),
            "relationship": link_type.get("inward", ""),
        })

# Extract SFDC cases
sfdc_count = f.get("customfield_10978")
sfdc_links = f.get("customfield_10979")

# Epic context
epic_key = f.get("customfield_10014")

# Available transitions
transitions = [{"id": t["id"], "name": t["name"]} for t in transitions_data.get("transitions", [])]

# Blocked info
blocked = (f.get("customfield_10517") or {}).get("value", "False") == "True"
blocked_reason = f.get("customfield_10483")
blocked_text = adf_mod.adf_to_text(blocked_reason).strip() if isinstance(blocked_reason, dict) else ""

result = {
    "key": issue.get("key", ""),
    "summary": f.get("summary", ""),
    "description": desc_text,
    "status": f.get("status", {}).get("name", ""),
    "statusCategory": f.get("status", {}).get("statusCategory", {}).get("key", ""),
    "assignee": (f.get("assignee") or {}).get("displayName", "Unassigned"),
    "assigneeEmail": (f.get("assignee") or {}).get("emailAddress", ""),
    "priority": f.get("priority", {}).get("name", ""),
    "type": f.get("issuetype", {}).get("name", ""),
    "points": f.get("customfield_10028") or 0,
    "fixVersions": [v.get("name", "") for v in (f.get("fixVersions") or [])],
    "epicKey": epic_key,
    "releaseBlocker": f.get("customfield_10847"),
    "blocked": blocked,
    "blockedReason": blocked_text,
    "sfdcCaseCount": sfdc_count,
    "sfdcLinks": sfdc_links,
    "linkedIssues": linked,
    "comments": comments,
    "transitions": transitions,
}

print(json.dumps(result))
PYEOF
}

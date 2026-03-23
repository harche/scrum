#!/bin/bash
# Composite: epic-progress <team>
# Epics the current user is contributing to, with children progress
# 2 bulk queries for all epics (was 2 per epic — 2N total)
# Serves: /my-epics

[[ -n "${_COMPOSITE_EPIC_PROGRESS_LOADED:-}" ]] && return 0
_COMPOSITE_EPIC_PROGRESS_LOADED=1

cmd_epic_progress() {
  local team="${1:?Team required}"

  team_config "$team"
  _init_auth

  local user_email="$JIRA_USER"

  # Get sprint + issues
  local sprint_json
  sprint_json=$(team_sprint "$team" active 2>/dev/null) || {
    sprint_json=$(team_sprint "$team" future 2>/dev/null) || {
      echo '{"error":"No active or future sprint found for '"$team"'"}' >&2; return 1
    }
    _log "WARN" "No active sprint — using future sprint"
  }

  local sprint_id
  sprint_id=$(echo "$sprint_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

  local issues_json
  issues_json=$(cmd_sprint_issues "$sprint_id")

  # Extract unique epic keys for the user's items
  local epic_keys
  epic_keys=$(python3 -c "
import json, sys
data = json.loads(sys.argv[1])
user = sys.argv[2]
epics = set()
for i in data.get('issues', []):
    f = i.get('fields', {})
    a = f.get('assignee') or {}
    if a.get('emailAddress', '') == user or a.get('displayName', '') == user:
        ek = f.get('customfield_10014')
        if ek:
            epics.add(ek)
for e in sorted(epics):
    print(e)
" "$issues_json" "$user_email")

  if [[ -z "$epic_keys" ]]; then
    python3 -c "
import json, sys
sprint = json.loads(sys.argv[1])
print(json.dumps({'sprint': {'id': sprint['id'], 'name': sprint['name']}, 'epics': [], 'summary': {'totalEpics': 0}}))
" "$sprint_json"
    return 0
  fi

  # Build comma-separated key lists for bulk JQL
  local keys_csv keys_quoted
  keys_csv=$(echo "$epic_keys" | tr '\n' ',' | sed 's/,$//')
  keys_quoted=$(echo "$epic_keys" | sed 's/.*/"&"/' | tr '\n' ',' | sed 's/,$//')

  # 2 bulk queries (was 2 per epic)
  parallel_init
  parallel_run "epics" cmd_search "key in (${keys_csv})" 50
  parallel_run "children" cmd_search "\"Epic Link\" in (${keys_quoted}) ORDER BY status ASC" 200
  parallel_wait_all 2>/dev/null || true

  python3 - "$sprint_json" "$issues_json" "$(parallel_get epics)" "$(parallel_get children)" "$user_email" <<'PYEOF'
import json, sys

sprint = json.loads(sys.argv[1])
all_issues = json.loads(sys.argv[2])
epics_data = json.loads(sys.argv[3])
children_data = json.loads(sys.argv[4])
user_email = sys.argv[5]

# Build epic map by key
epic_map = {}
for e in epics_data.get("issues", []):
    epic_map[e["key"]] = e

# Group children by epic link
children_by_epic = {}
for c in children_data.get("issues", []):
    ek = c.get("fields", {}).get("customfield_10014")
    if ek:
        children_by_epic.setdefault(ek, []).append(c)

# My sprint items by epic
my_sprint_items = {}
for i in all_issues.get("issues", []):
    f = i.get("fields", {})
    a = f.get("assignee") or {}
    ek = f.get("customfield_10014")
    if ek:
        item = {
            "key": i.get("key", ""), "summary": f.get("summary", ""),
            "status": f.get("status", {}).get("name", ""),
            "statusCategory": f.get("status", {}).get("statusCategory", {}).get("key", ""),
            "points": f.get("customfield_10028") or 0,
            "type": f.get("issuetype", {}).get("name", ""),
            "mine": a.get("emailAddress", "") == user_email or a.get("displayName", "") == user_email,
            "assignee": a.get("displayName", "Unassigned"),
        }
        my_sprint_items.setdefault(ek, []).append(item)

epics_out = []
for ek in sorted(epic_map.keys()):
    epic = epic_map[ek]
    ef = epic.get("fields", {})
    epic_children = children_by_epic.get(ek, [])

    children = []
    done_count = 0
    in_progress_count = 0
    todo_count = 0
    total_children = 0

    for child in epic_children:
        cf = child.get("fields", {})
        sc = cf.get("status", {}).get("statusCategory", {}).get("key", "")
        total_children += 1
        if sc == "done":
            done_count += 1
        elif sc == "indeterminate":
            in_progress_count += 1
        else:
            todo_count += 1
        children.append({
            "key": child.get("key", ""),
            "summary": cf.get("summary", ""),
            "status": cf.get("status", {}).get("name", ""),
            "statusCategory": sc,
            "assignee": (cf.get("assignee") or {}).get("displayName", "Unassigned"),
            "points": cf.get("customfield_10028") or 0,
        })

    pct = round(done_count / total_children * 100) if total_children else 0

    # Split sprint items into mine vs others
    sprint_items = my_sprint_items.get(ek, [])
    my_items = [i for i in sprint_items if i["mine"]]
    other_items = [i for i in sprint_items if not i["mine"]]

    epics_out.append({
        "key": ek,
        "summary": ef.get("summary", ""),
        "status": ef.get("status", {}).get("name", ""),
        "assignee": (ef.get("assignee") or {}).get("displayName", "Unassigned"),
        "progress": {
            "total": total_children, "done": done_count,
            "inProgress": in_progress_count, "toDo": todo_count,
            "percent": pct,
        },
        "myItems": my_items,
        "otherItems": other_items,
        "allChildren": children,
    })

at_risk = [e for e in epics_out if e["progress"]["toDo"] > e["progress"]["done"]]
near_complete = [e for e in epics_out if e["progress"]["percent"] >= 80]

result = {
    "sprint": {"id": sprint["id"], "name": sprint["name"]},
    "epics": epics_out,
    "summary": {
        "totalEpics": len(epics_out),
        "nearComplete": [{"key": e["key"], "summary": e["summary"], "percent": e["progress"]["percent"]} for e in near_complete],
        "atRisk": [{"key": e["key"], "summary": e["summary"], "toDo": e["progress"]["toDo"]} for e in at_risk],
    },
}
print(json.dumps(result))
PYEOF
}

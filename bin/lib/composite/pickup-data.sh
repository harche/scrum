#!/bin/bash
# Composite: pickup-data <team>
# All available unassigned work: sprint items + bugs (with escalation tagging)
# 2 queries (was 3 — merged bugs + escalations into 1)
# Serves: /pickup

[[ -n "${_COMPOSITE_PICKUP_LOADED:-}" ]] && return 0
_COMPOSITE_PICKUP_LOADED=1

cmd_pickup_data() {
  local team="${1:?Team required}"

  team_config "$team"

  local sprint_json
  sprint_json=$(team_sprint "$team" active 2>/dev/null) || {
    sprint_json=$(team_sprint "$team" future 2>/dev/null) || {
      echo '{"error":"No active or future sprint found for '"$team"'"}' >&2; return 1
    }
    _log "WARN" "No active sprint — using future sprint"
  }

  local sprint_id
  sprint_id=$(echo "$sprint_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

  local bug_fields="[\"key\",\"summary\",\"status\",\"assignee\",\"priority\",\"issuetype\",\"${CF_STORY_POINTS}\"]"

  # 2 queries: sprint items + unassigned bugs
  parallel_init
  parallel_run "issues" cmd_sprint_issues "$sprint_id"
  parallel_run "bugs" cmd_search \
    "project = OCPBUGS AND component in (${TEAM_BUG_COMPONENTS}) AND assignee is EMPTY AND status not in (CLOSED, Verified, Done) ORDER BY priority ASC, created ASC" 50 "$bug_fields"
  parallel_wait_all || true

  python3 - "$sprint_json" "$(parallel_get issues)" "$(parallel_get bugs)" <<'PYEOF'
import json, sys

sprint = json.loads(sys.argv[1])
issues_data = json.loads(sys.argv[2])
bugs_data = json.loads(sys.argv[3])

def extract(data):
    items = []
    for i in data.get("issues", []):
        f = i.get("fields", {})
        items.append({
            "key": i.get("key", ""), "summary": f.get("summary", ""),
            "status": f.get("status", {}).get("name", ""),
            "priority": f.get("priority", {}).get("name", ""),
            "type": f.get("issuetype", {}).get("name", ""),
            "points": f.get("customfield_10028") or 0,
            "assignee": (f.get("assignee") or {}).get("displayName", "Unassigned"),
        })
    return items

# Unassigned sprint items (bot account is the default assignee — treat as unassigned)
BOT_ACCOUNTS = {"Node Team Bot Account"}
unassigned_sprint = [i for i in extract(issues_data) if i["assignee"] in ({"Unassigned"} | BOT_ACCOUNTS)]
unassigned_bugs = extract(bugs_data)

result = {
    "sprint": {"id": sprint["id"], "name": sprint["name"]},
    "unassignedSprintItems": unassigned_sprint,
    "unassignedBugs": unassigned_bugs,
    "summary": {
        "sprintItems": len(unassigned_sprint),
        "bugs": len(unassigned_bugs),
    },
}
print(json.dumps(result))
PYEOF
}

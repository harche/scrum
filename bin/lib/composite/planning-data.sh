#!/bin/bash
# Composite: planning-data <team>
# Full planning package: carryovers + scheduled next sprint + backlog + bugs
# Serves: /sprint-plan

[[ -n "${_COMPOSITE_PLANNING_LOADED:-}" ]] && return 0
_COMPOSITE_PLANNING_LOADED=1

cmd_planning_data() {
  local team="${1:?Team required}"

  team_config "$team"

  # ── Sprint discovery ─────────────────────────────────────────────────────
  local active_sprint future_sprint
  active_sprint=$(team_sprint "$team" active) || { echo "$active_sprint" >&2; return 1; }

  local active_id
  active_id=$(echo "$active_sprint" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

  future_sprint=$(team_sprint "$team" future 2>/dev/null) || future_sprint='{"error":"No future sprint"}'

  local future_id=""
  future_id=$(echo "$future_sprint" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null) || true

  # ── Parallel: active issues + future issues + backlog + unscheduled bugs + roster
  parallel_init

  parallel_run "active_issues" cmd_sprint_issues "$active_id"

  if [[ -n "$future_id" ]]; then
    parallel_run "future_issues" cmd_sprint_issues "$future_id"
  fi

  parallel_run "backlog" cmd_search \
    "project = OCPNODE AND sprint is EMPTY AND status not in (Closed, Done) AND type in (Story, Task, Spike) ORDER BY priority ASC, created DESC" 30

  parallel_run "unscheduled_bugs" cmd_search \
    "project = OCPBUGS AND component in (${TEAM_BUG_COMPONENTS}) AND sprint is EMPTY AND status not in (Closed, Done, Verified) ORDER BY priority ASC, created DESC" 30

  parallel_run "roster" team_roster "$team"

  parallel_wait_all || true

  local active_issues future_issues backlog bugs roster_json
  active_issues=$(parallel_get "active_issues")
  future_issues=$(parallel_get "future_issues" 2>/dev/null || echo '{"issues":[]}')
  backlog=$(parallel_get "backlog")
  bugs=$(parallel_get "unscheduled_bugs")
  roster_json=$(parallel_get "roster")

  python3 - "$active_sprint" "$future_sprint" "$backlog" "$bugs" "$roster_json" "$future_issues" "$active_issues" <<'PYEOF'
import json, sys

active_sprint = json.loads(sys.argv[1])
future_sprint = json.loads(sys.argv[2])
backlog_data = json.loads(sys.argv[3])
bugs_data = json.loads(sys.argv[4])
roster = json.loads(sys.argv[5])
future_data = json.loads(sys.argv[6])
active_data = json.loads(sys.argv[7])

def extract_items(data):
    items = []
    for i in data.get("issues", []):
        f = i.get("fields", {})
        items.append({
            "key": i.get("key", ""),
            "summary": f.get("summary", ""),
            "status": f.get("status", {}).get("name", ""),
            "statusCategory": f.get("status", {}).get("statusCategory", {}).get("key", ""),
            "assignee": (f.get("assignee") or {}).get("displayName", "Unassigned"),
            "points": f.get("customfield_10028") or 0,
            "type": f.get("issuetype", {}).get("name", ""),
            "priority": f.get("priority", {}).get("name", ""),
        })
    return items

active_items = extract_items(active_data)
carryovers = [i for i in active_items if i["statusCategory"] != "done"]
done_items = [i for i in active_items if i["statusCategory"] == "done"]
scheduled = extract_items(future_data)
backlog_items = extract_items(backlog_data)
bug_items = extract_items(bugs_data)

result = {
    "activeSprint": active_sprint,
    "futureSprint": future_sprint if "error" not in future_sprint else None,
    "wrapUp": {
        "done": done_items,
        "carryovers": carryovers,
        "doneCount": len(done_items),
        "carryoverCount": len(carryovers),
        "donePoints": sum(i["points"] for i in done_items),
        "carryoverPoints": sum(i["points"] for i in carryovers),
    },
    "scheduled": scheduled,
    "backlogCandidates": backlog_items,
    "unscheduledBugs": bug_items,
    "roster": roster,
}

print(json.dumps(result))
PYEOF
}

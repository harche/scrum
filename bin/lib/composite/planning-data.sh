#!/bin/bash
# Composite: planning-data <team>
# Full planning package: carryovers + scheduled next sprint + backlog + bugs
# Serves: /sprint-plan

[[ -n "${_COMPOSITE_PLANNING_LOADED:-}" ]] && return 0
_COMPOSITE_PLANNING_LOADED=1

cmd_planning_data() {
  local team="${1:?Team required}"

  team_config "$team"

  # ── Sprint discovery (active preferred, fall back to last closed) ────────
  local active_sprint future_sprint
  active_sprint=$(team_sprint_fallback "$team") || { echo "$active_sprint" >&2; return 1; }

  local active_id
  active_id=$(echo "$active_sprint" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

  future_sprint=$(team_sprint "$team" future 2>/dev/null) || future_sprint='{"error":"No future sprint"}'

  local future_id=""
  future_id=$(echo "$future_sprint" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null) || true

  # ── Parallel: active issues + future issues + backlog + unscheduled bugs + roster
  parallel_init

  parallel_run "active_issues" cmd_sprint_issues "$active_id" 100 "$ISSUE_FIELDS" "ORDER BY assignee ASC, status ASC"

  if [[ -n "$future_id" ]]; then
    parallel_run "future_issues" cmd_sprint_issues "$future_id" 100 "$ISSUE_FIELDS" "ORDER BY assignee ASC, status ASC"
  fi

  parallel_run "backlog" cmd_search \
    "project = OCPNODE AND sprint is EMPTY AND status not in (Closed, Done) AND type in (Story, Task, Spike) ORDER BY assignee ASC, priority ASC, created DESC" 30

  parallel_run "unscheduled_bugs" cmd_search \
    "project = OCPBUGS AND component in (${TEAM_BUG_COMPONENTS}) AND sprint is EMPTY AND status not in (Closed, Done, Verified) ORDER BY assignee ASC, priority ASC, created DESC" 30

  parallel_run "roster" team_roster "$team"

  parallel_wait_all || true

  local active_issues future_issues backlog bugs roster_json
  active_issues=$(parallel_get "active_issues")
  future_issues=$(parallel_get "future_issues" 2>/dev/null || echo '{"issues":[]}')
  backlog=$(parallel_get "backlog")
  bugs=$(parallel_get "unscheduled_bugs")
  roster_json=$(parallel_get "roster")

  # ── Fetch comments for carryover items (not-done) ──────────────────────
  local carryover_keys
  carryover_keys=$(echo "$active_issues" | python3 -c "
import json, sys
data = json.load(sys.stdin)
keys = [i['key'] for i in data.get('issues', [])
        if i.get('fields', {}).get('status', {}).get('statusCategory', {}).get('key', '') != 'done']
print(' '.join(keys))
")

  parallel_cleanup 2>/dev/null || true
  parallel_init

  local count=0
  for key in $carryover_keys; do
    parallel_run "comments_${key}" cmd_comments "$key"
    count=$((count + 1))
    if (( count % 5 == 0 )); then
      parallel_wait_all 2>/dev/null || true
    fi
  done
  parallel_wait_all 2>/dev/null || true

  local comments_combined="{"
  local first=true
  for key in $carryover_keys; do
    local c
    c=$(parallel_get "comments_${key}" 2>/dev/null)
    if [[ -n "$c" && "$c" != *"error"* ]]; then
      if [[ "$first" == "true" ]]; then
        first=false
      else
        comments_combined+=","
      fi
      comments_combined+="\"${key}\":${c}"
    fi
  done
  comments_combined+="}"

  local adf_py
  adf_py="$(cd "$(dirname "${BASH_SOURCE[0]}")/../util" && pwd)/adf.py"

  python3 - "$active_sprint" "$future_sprint" "$backlog" "$bugs" "$roster_json" "$future_issues" "$active_issues" "$comments_combined" "$adf_py" <<'PYEOF'
import json, sys, importlib.util

active_sprint = json.loads(sys.argv[1])
future_sprint = json.loads(sys.argv[2])
backlog_data = json.loads(sys.argv[3])
bugs_data = json.loads(sys.argv[4])
roster = json.loads(sys.argv[5])
future_data = json.loads(sys.argv[6])
active_data = json.loads(sys.argv[7])
all_comments = json.loads(sys.argv[8])
adf_py_path = sys.argv[9]

# Load ADF converter
spec = importlib.util.spec_from_file_location("adf", adf_py_path)
adf_mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adf_mod)

def latest_comment_for(key):
    comments = all_comments.get(key, {}).get("comments", [])
    if not comments:
        return None
    last_c = comments[-1]
    body_adf = last_c.get("body", {})
    body_text = adf_mod.adf_to_text(body_adf).strip() if isinstance(body_adf, dict) else str(body_adf)
    return {
        "author": last_c.get("author", {}).get("displayName", "Unknown"),
        "created": last_c.get("created", "")[:10],
        "body": body_text[:200],
    }

def extract_items(data, with_comments=False):
    items = []
    for i in data.get("issues", []):
        f = i.get("fields", {})
        item = {
            "key": i.get("key", ""),
            "summary": f.get("summary", ""),
            "status": f.get("status", {}).get("name", ""),
            "statusCategory": f.get("status", {}).get("statusCategory", {}).get("key", ""),
            "assignee": (f.get("assignee") or {}).get("displayName", "Unassigned"),
            "points": f.get("customfield_10028") or 0,
            "type": f.get("issuetype", {}).get("name", ""),
            "priority": f.get("priority", {}).get("name", ""),
        }
        if with_comments:
            item["latestComment"] = latest_comment_for(i.get("key", ""))
        items.append(item)
    return items

def group_by_assignee(items):
    grouped = {}
    for item in items:
        assignee = item["assignee"]
        if assignee not in grouped:
            grouped[assignee] = {"items": [], "count": 0, "points": 0}
        grouped[assignee]["items"].append(item)
        grouped[assignee]["count"] += 1
        grouped[assignee]["points"] += item["points"]
    return grouped

active_items = extract_items(active_data, with_comments=True)
carryovers = [i for i in active_items if i["statusCategory"] != "done"]
done_items = [i for i in active_items if i["statusCategory"] == "done"]
scheduled = extract_items(future_data)
backlog_items = extract_items(backlog_data)
bug_items = extract_items(bugs_data)

carryovers_by_person = group_by_assignee(carryovers)
done_by_person = group_by_assignee(done_items)
scheduled_by_person = group_by_assignee(scheduled)
bugs_by_person = group_by_assignee(bug_items)

# Build per-person summary ordered by roster, then any non-roster assignees
roster_names = [r["name"] for r in roster]
roster_github = {r["name"]: r.get("github", "") for r in roster}
all_names = set()
for g in [carryovers_by_person, done_by_person, scheduled_by_person, bugs_by_person]:
    all_names.update(g.keys())
# Roster members first (in roster order), then others alphabetically
ordered = [n for n in roster_names if n in all_names]
ordered += sorted(n for n in all_names if n not in roster_names)

team_summary = []
for name in ordered:
    co = carryovers_by_person.get(name, {"items": [], "count": 0, "points": 0})
    dn = done_by_person.get(name, {"items": [], "count": 0, "points": 0})
    sc = scheduled_by_person.get(name, {"items": [], "count": 0, "points": 0})
    bg = bugs_by_person.get(name, {"items": [], "count": 0, "points": 0})
    team_summary.append({
        "name": name,
        "github": roster_github.get(name, ""),
        "carryovers": co["items"],
        "carryoverCount": co["count"],
        "carryoverPoints": co["points"],
        "done": dn["items"],
        "doneCount": dn["count"],
        "donePoints": dn["points"],
        "scheduled": sc["items"],
        "scheduledCount": sc["count"],
        "scheduledPoints": sc["points"],
        "bugs": bg["items"],
        "bugCount": bg["count"],
        "totalItems": co["count"] + sc["count"],
        "totalPoints": co["points"] + sc["points"],
    })

# Separate unassigned backlog for the pool section
assigned_backlog = [i for i in backlog_items if i["assignee"] != "Unassigned"]
unassigned_backlog = [i for i in backlog_items if i["assignee"] == "Unassigned"]

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
    "teamSummary": team_summary,
    "scheduled": scheduled,
    "backlogCandidates": backlog_items,
    "assignedBacklog": assigned_backlog,
    "unassignedBacklog": unassigned_backlog,
    "unscheduledBugs": bug_items,
    "roster": roster,
}

print(json.dumps(result))
PYEOF
}

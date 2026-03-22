#!/bin/bash
# Composite: my-board-data <team>
# Sprint dashboard pre-filtered to the current user (JIRA_EMAIL)
# Serves: /my-board

[[ -n "${_COMPOSITE_MY_BOARD_LOADED:-}" ]] && return 0
_COMPOSITE_MY_BOARD_LOADED=1

cmd_my_board_data() {
  local team="${1:?Team required}"

  team_config "$team"
  _init_auth

  local sprint_json
  sprint_json=$(team_sprint "$team" active) || { echo "$sprint_json" >&2; return 1; }

  local sprint_id
  sprint_id=$(echo "$sprint_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

  local issues_json
  issues_json=$(cmd_sprint_issues "$sprint_id")

  python3 - "$sprint_json" "$issues_json" "${JIRA_USER}" <<'PYEOF'
import json, sys
from datetime import datetime, timezone

sprint = json.loads(sys.argv[1])
data = json.loads(sys.argv[2])
user_email = sys.argv[3]
issues = data.get("issues", [])

start = datetime.fromisoformat(sprint["startDate"].replace("Z", "+00:00"))
end = datetime.fromisoformat(sprint["endDate"].replace("Z", "+00:00"))
now = datetime.now(timezone.utc)
total_days = max((end - start).days, 1)
elapsed = min(max((now - start).days, 0), total_days)
remaining = max(total_days - elapsed, 0)

STATUS_ORDER = {"done": 0, "codeReview": 1, "inProgress": 2, "modified": 3, "toDo": 4, "other": 5}
by_status = {}
total_pts = 0
done_pts = 0
flags = []

for issue in issues:
    f = issue.get("fields", {})
    assignee = f.get("assignee") or {}
    if assignee.get("emailAddress", "") != user_email and assignee.get("displayName", "") != user_email:
        continue

    key = issue.get("key", "")
    summary = f.get("summary", "")
    status_name = f.get("status", {}).get("name", "")
    status_cat = f.get("status", {}).get("statusCategory", {}).get("key", "")
    pts = f.get("customfield_10028") or 0
    itype = f.get("issuetype", {}).get("name", "")
    blocked = (f.get("customfield_10517") or {}).get("value", "False") == "True"
    blocked_reason = f.get("customfield_10483")
    br_text = ""
    if isinstance(blocked_reason, dict):
        # simple ADF extract
        def _adf(n):
            if not isinstance(n, dict): return ""
            t = n.get("text", "") if n.get("type") == "text" else ""
            for c in n.get("content", []): t += _adf(c)
            return t
        br_text = _adf(blocked_reason).strip()

    total_pts += pts
    if status_cat == "done":
        group = "done"; done_pts += pts
    elif status_name == "Code Review":
        group = "codeReview"
    elif status_name == "MODIFIED":
        group = "modified"
    elif status_cat == "indeterminate" or status_name == "In Progress":
        group = "inProgress"
    elif status_cat == "new" or status_name in ("To Do", "NEW"):
        group = "toDo"
    else:
        group = "other"

    item = {"key": key, "summary": summary, "status": status_name, "statusGroup": group,
            "points": pts, "type": itype, "blocked": blocked, "blockedReason": br_text}
    by_status.setdefault(group, []).append(item)

    if blocked:
        flags.append({"key": key, "summary": summary, "reason": br_text or "Blocked (no reason given)"})
    if not pts and group != "done":
        flags.append({"key": key, "summary": summary, "reason": "No story points"})
    if group == "toDo" and remaining <= 3:
        flags.append({"key": key, "summary": summary, "reason": f"Still To Do with {remaining} days left"})

ordered = {}
for g in sorted(by_status.keys(), key=lambda x: STATUS_ORDER.get(x, 99)):
    ordered[g] = by_status[g]

total_items = sum(len(v) for v in by_status.values())
result = {
    "sprint": {"id": sprint["id"], "name": sprint["name"], "startDate": sprint["startDate"],
               "endDate": sprint["endDate"], "daysElapsed": elapsed, "daysTotal": total_days, "daysRemaining": remaining},
    "summary": {"total": total_items, "done": len(by_status.get("done", [])),
                "inProgress": len(by_status.get("inProgress", [])) + len(by_status.get("codeReview", [])),
                "toDo": len(by_status.get("toDo", [])),
                "totalPoints": total_pts, "donePoints": done_pts},
    "byStatus": ordered,
    "flags": flags,
}
print(json.dumps(result))
PYEOF
}

#!/bin/bash
# API commands: health check — validates field metadata against Jira
# Sourced by jira.sh — requires core.sh

[[ -n "${_API_HEALTH_LOADED:-}" ]] && return 0
_API_HEALTH_LOADED=1

cmd_health_check() {
  _init_auth

  # Fetch all field definitions from Jira (1 API call)
  local fields_json
  fields_json=$(_curl "${JIRA_BASE}/rest/api/3/field")

  # Validate our custom field IDs against actual Jira metadata
  python3 - "$fields_json" <<PYEOF
import json, sys

fields_data = json.loads(sys.argv[1])

# Build lookup: id → {name, type}
field_map = {}
for f in fields_data:
    fid = f.get("id", "")
    field_map[fid] = {
        "name": f.get("name", ""),
        "type": f.get("schema", {}).get("type", "unknown"),
        "custom": f.get("custom", False),
    }

# Expected fields from core.sh — id, expected name, expected type
expected = [
    ("${CF_SPRINT}",          "Sprint",              "array"),
    ("${CF_STORY_POINTS}",    "Story Points",        "number"),
    ("${CF_EPIC_LINK}",       "Epic Link",           "any"),
    ("${CF_TARGET_VERSION}",  "Target Version",      "any"),
    ("${CF_RELEASE_BLOCKER}", "Release Blocker",     "option"),
    ("${CF_SFDC_COUNTER}",    "SFDC Cases Counter",  "string"),
    ("${CF_SFDC_LINKS}",      "SFDC Cases Links",    "any"),
    ("${CF_SEVERITY}",        "Severity",            "option"),
    ("${CF_BLOCKED}",         "Blocked",             "option"),
    ("${CF_BLOCKED_REASON}",  "Blocked Reason",      "any"),
]

results = []
errors = 0
warnings = 0

for field_id, expected_name, expected_type in expected:
    actual = field_map.get(field_id)
    if actual is None:
        results.append({"id": field_id, "expected": expected_name, "status": "NOT_FOUND"})
        errors += 1
    else:
        actual_name = actual["name"]
        actual_type = actual["type"]
        issues = []

        if actual_name != expected_name:
            issues.append(f"name changed: '{actual_name}' (expected '{expected_name}')")
            warnings += 1

        if expected_type != "any" and actual_type != expected_type:
            issues.append(f"type changed: '{actual_type}' (expected '{expected_type}')")
            warnings += 1

        status = "OK" if not issues else "CHANGED"
        entry = {"id": field_id, "expected": expected_name, "actual": actual_name,
                 "type": actual_type, "status": status}
        if issues:
            entry["issues"] = issues
        results.append(entry)

# Also check standard fields we depend on
standard_fields = ["status", "assignee", "priority", "issuetype", "fixVersions",
                   "components", "summary", "updated", "created"]
missing_standard = [f for f in standard_fields if f not in field_map]
if missing_standard:
    errors += len(missing_standard)

# Check API connectivity
api_ok = len(fields_data) > 0

print(json.dumps({
    "status": "HEALTHY" if errors == 0 and warnings == 0 else "DEGRADED" if errors == 0 else "UNHEALTHY",
    "summary": {
        "fieldsChecked": len(expected),
        "errors": errors,
        "warnings": warnings,
        "totalJiraFields": len(fields_data),
        "apiConnectivity": api_ok,
    },
    "fields": results,
    "missingStandardFields": missing_standard,
}, indent=2))
PYEOF
}

#!/usr/bin/env python3
"""Convert Atlassian Document Format (ADF) JSON to plain text.

Usage:
  echo '<adf-json>' | python3 adf.py                    # Convert raw ADF node
  echo '<issue-json>' | python3 adf.py --field description  # Extract ADF field from issue
  echo '<comments-json>' | python3 adf.py --comments     # Extract all comments with metadata
  echo '<issue-json>' | python3 adf.py --issues          # Extract from search/sprint-issues result
"""

import json
import sys
from datetime import datetime, timedelta, timezone


def adf_to_text(node):
    """Recursively convert an ADF node tree to plain text."""
    if isinstance(node, str):
        return node
    if not isinstance(node, dict):
        return ""

    node_type = node.get("type", "")
    text = ""

    if node_type == "text":
        t = node.get("text", "")
        # Check for link marks
        for mark in node.get("marks", []):
            if mark.get("type") == "link":
                href = mark.get("attrs", {}).get("href", "")
                if href and href != t:
                    t = f"{t} ({href})"
        text = t
    elif node_type in ("blockCard", "inlineCard", "embedCard"):
        url = node.get("attrs", {}).get("url", "")
        if url:
            text = url + "\n"
    elif node_type == "mediaInline":
        alt = node.get("attrs", {}).get("alt", "")
        text = f"[{alt or 'attachment'}]"
    elif node_type == "mention":
        text = "@" + node.get("attrs", {}).get("text", node.get("attrs", {}).get("id", ""))

    for child in node.get("content", []):
        text += adf_to_text(child)

    if node_type in ("paragraph", "heading", "listItem", "blockquote"):
        text += "\n"
    elif node_type == "hardBreak":
        text += "\n"
    elif node_type in ("codeBlock",):
        text += "\n"
    return text


def extract_field(issue, field_name):
    """Extract an ADF field from an issue JSON and convert to text."""
    fields = issue.get("fields", issue)
    adf = fields.get(field_name)
    if not adf:
        return ""
    if isinstance(adf, str):
        return adf
    return adf_to_text(adf).strip()


def extract_comments(data, since_days=None):
    """Extract comments from a comments API response.

    Returns list of {author, date, body} dicts.
    If since_days is set, only returns comments from the last N days.
    """
    cutoff = None
    if since_days is not None:
        cutoff = datetime.now(timezone.utc) - timedelta(days=since_days)

    comments = data.get("comments", [])
    results = []
    for c in comments:
        created = c.get("created", "")
        if cutoff and created:
            try:
                dt = datetime.fromisoformat(created.replace("Z", "+00:00"))
                if dt < cutoff:
                    continue
            except (ValueError, TypeError):
                pass

        author = c.get("author", {}).get("displayName", "Unknown")
        body_adf = c.get("body", {})
        body_text = adf_to_text(body_adf).strip() if isinstance(body_adf, dict) else str(body_adf)

        results.append({
            "author": author,
            "created": created,
            "body": body_text,
        })
    return results


def extract_issues(data):
    """Extract description text from each issue in a search/sprint-issues response."""
    issues = data.get("issues", [])
    results = []
    for issue in issues:
        key = issue.get("key", "")
        fields = issue.get("fields", {})
        desc_adf = fields.get("description")
        desc_text = ""
        if isinstance(desc_adf, dict):
            desc_text = adf_to_text(desc_adf).strip()
        elif isinstance(desc_adf, str):
            desc_text = desc_adf.strip()

        blocked_reason = fields.get("customfield_10483")
        blocked_text = ""
        if isinstance(blocked_reason, dict):
            blocked_text = adf_to_text(blocked_reason).strip()
        elif isinstance(blocked_reason, str):
            blocked_text = blocked_reason.strip()

        results.append({
            "key": key,
            "description": desc_text,
            "blockedReason": blocked_text,
        })
    return results


def main():
    args = sys.argv[1:]
    data = json.load(sys.stdin)

    if "--field" in args:
        idx = args.index("--field")
        field_name = args[idx + 1] if idx + 1 < len(args) else "description"
        print(extract_field(data, field_name))

    elif "--comments" in args:
        since = None
        if "--since-days" in args:
            si = args.index("--since-days")
            since = int(args[si + 1]) if si + 1 < len(args) else None
        results = extract_comments(data, since_days=since)
        print(json.dumps(results))

    elif "--issues" in args:
        results = extract_issues(data)
        print(json.dumps(results))

    else:
        # Raw ADF node conversion
        print(adf_to_text(data).strip())


if __name__ == "__main__":
    main()

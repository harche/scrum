Deep-dive investigation on a Jira issue. Provide the issue key as an argument: /investigate OCPNODE-1234

Argument: $ARGUMENTS (the issue key, e.g., OCPNODE-4161 or OCPBUGS-65805)

## Steps

1. Get the full issue:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh get $ARGUMENTS`

2. Get comments:
   `JIRA_EMAIL="harpatil@redhat.com" bin/jira.sh comments $ARGUMENTS`

3. Check for linked issues in the issue fields (issuelinks array). For each linked issue, briefly note its key, summary, status, and link type.

4. If the issue has an Epic Link (customfield_10014), fetch the epic to provide broader context.

5. If SFDC Cases Links (customfield_10979) is populated, note the case numbers.

**Note:** API v3 returns `description` and comment `body` fields in Atlassian Document Format (ADF — a JSON structure). Extract readable text by recursively walking the ADF nodes: collect `text` from nodes with `type: "text"`, and add newlines after `paragraph`, `heading`, `listItem`, `blockquote`, and `hardBreak` nodes.

## Output

### Issue Overview
- Key, summary, type, status, priority, assignee
- Created date, updated date
- Sprint, story points, fix version
- Epic (if linked)
- Clickable URL

### Description
Show the full description (converted from ADF to readable text).

### Comments
Show comments in chronological order with author and date. Convert ADF body to readable text. Summarize if there are more than 5.

### Linked Issues
Table: link type, key, summary, status

### Support Cases
List any linked SFDC cases.

### Timeline
Key status changes and dates (inferred from comments/description).

### Summary
Brief assessment: what's the current state, what's blocking progress, what needs to happen next.

### Next Steps
After presenting the investigation, use `AskUserQuestion` to ask: "What would you like to do with this issue?" with options:
- Set priority
- Assign / reassign
- Transition status (e.g., move to POST, MODIFIED)
- Add a comment
- Done (no action needed)

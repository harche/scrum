Review the current conversation for every error, failure, or workaround encountered — including HTTP errors (400/401/403/500), bash errors, empty results that should have had data, silent workarounds, or manual overrides.

For each issue found:

1. **List all failures.** Present a numbered summary table of every error or workaround observed in this session:
   - What failed (tool, command, API call)
   - The error or symptom
   - How it was handled (workaround, retry, ignored, etc.)

2. **Diagnose each one.** For each failure, read the relevant source code (`bin/jira.sh`, slash command files, `CLAUDE.md`, etc.) and identify the root cause. Use `AskUserQuestion` to confirm your diagnosis before proceeding.

3. **Propose fixes one at a time.** For each issue:
   - Show the root cause
   - Draft the specific code change (show the diff)
   - Use `AskUserQuestion` to ask: "Apply this fix?" (options: Yes / Skip / Modify)
   - Only apply if the user approves

4. **Verify each fix.** After applying a fix, re-run the original failing operation to confirm it works. Report the result to the user.

5. **Update docs if needed.** If any fix changes a command signature or adds new behavior, update `CLAUDE.md` accordingly. Use `AskUserQuestion` to confirm doc changes before applying.

6. **Summary.** After processing all issues, show a final summary of what was fixed, what was skipped, and any remaining known issues.

If no failures were encountered in this session, say so and offer to run a health check on `bin/jira.sh` (test auth, sprint queries, search) to proactively find issues.

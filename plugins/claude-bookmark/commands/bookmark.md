---
description: Bookmark current Claude Code session for later resume
argument-hint: "<name?>"
allowed-tools: Bash(bash:*)
---

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/bookmark.sh save-here "$PWD" "$ARGUMENTS"`

If the bash output above contains `<pending:...>`, no name was supplied.
Extract the placeholder name from inside the brackets (e.g. `<pending:pending-abc12345>` → `pending-abc12345`),
then generate a concise **1-sentence** summary of this conversation's main topic/point.
Read the recent user/assistant exchanges and capture what this session is really
about, in plain prose.

Examples of good 1-sentence names:
- `Designing a /bookmark slash command for Claude Code`
- `Debugging auth middleware token-refresh race condition`
- `Investigating the ingest pipeline backlog from last night`

Then run (quote both args — sentences contain spaces):

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/bookmark.sh rename "<placeholder-from-output>" "<your-generated-sentence>"`

If no `<pending:...>` marker appears, the user provided a name already — briefly confirm the bookmark was saved.

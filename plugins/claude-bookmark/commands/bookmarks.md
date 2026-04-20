---
description: List, resume, or delete saved Claude Code session bookmarks
argument-hint: "[list|resume <name>|delete <name>|prune]"
allowed-tools: Bash(bash:*)
---

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/bookmark.sh $ARGUMENTS`

Print the bash output above verbatim inside a fenced code block, with no extra commentary, summary, or `<tldr>`. If the output is empty, say so in one short line.

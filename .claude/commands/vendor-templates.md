---
description: Copy the shared .claude files from a Fleetwright templates repository into this project
argument-hint: [owner/repo]
---

Vendor the shared Claude Code configuration from the templates repository
`$ARGUMENTS` into this project's `.claude/` directory.

If `$ARGUMENTS` is empty, say that the repository is the one linked under
**You › Linked repositories › Templates** in the Fleetwright app and ask for it
as `owner/repo`; do not guess.

Then:

1. Clone it shallow into a temporary directory outside this project.
2. Copy `.claude/skills/`, `.claude/agents/` and `.claude/commands/` from it
   into this project's `.claude/`, file by file. Where a file already exists
   here and differs, show the diff and ask before replacing it.
3. Do **not** copy `.claude/settings.json` over this project's. Show the keys
   it would add and let me merge them.
4. Delete the temporary clone.

Finish by listing exactly which files were added and which were replaced.

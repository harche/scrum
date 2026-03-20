# `.agent` compatibility layer

This repository keeps the authoritative command docs in:
- `.claude/commands/*.md`

To keep Cursor agent workflows working without duplicating content, this folder provides a compatibility bridge:
- `.agent/commands` is a symlink to `.claude/commands`

Use `.agent` as the lookup path for Cursor tools, while editing workflows in `.claude/commands`.

```text
.agent/commands -> ../.claude/commands
```

Guidelines:
- Do **not** copy command files into `.agent`; keep `.claude/commands` as the source of truth.
- Add/modify command definitions only in `.claude/commands`.
- If the symlink is missing, recreate it with:

```bash
mkdir -p .agent && ln -sfn ../.claude/commands .agent/commands
```

## Token discipline

Skills in `.claude/skills/`. Apply automatically:

- **ponytail** — before writing ANY new code. Native → stdlib → existing project code → existing dep → write it. Grep before you write.
- **token-saver** — before reading ANY file. `rg` to locate, read the slice, never `cat` whole files. Max 3 files before stating a hypothesis.
- **superpowers** — any task touching 3+ files. Clarify → Design → Plan → Code → Verify. Stop at the gates.
- **caveman** — output style. No preamble, no restating the ask, no recap, no narration around code. Diffs not files. `caveman ultra` for max compression.

Defaults, always on:
- Answer first. Explain only if asked.
- Edits are targeted replacements; never re-emit an unchanged file.
- Cite `path:line` instead of pasting code back.
- Never re-read a file already in this session's context.
- "Should work" is banned. Verify or say unverified.

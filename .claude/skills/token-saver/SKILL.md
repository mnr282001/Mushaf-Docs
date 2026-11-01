---
name: token-saver
description: Use whenever reading files, exploring a codebase, debugging, or answering questions about existing code. Prevents dumping whole files into context by searching first and reading only the relevant passages. Triggers on "where is", "how does X work", "find", "fix the bug in", "what does this do", or any task requiring unfamiliar files.
---

# Token Saver

Never `cat` a file to find something. Search, then read the slice.

## Protocol

1. **Locate** — `rg -n "<symbol>" -g '!node_modules' -g '!dist'`
2. **Slice** — read only the matched range ± 20 lines. Use offset/limit, not full read.
3. **Expand once** — if the slice isn't enough, widen that one range. Do not open new files speculatively.
4. **Stop** — you have enough when you can name the exact lines to change.

## Budget

- Full file read allowed only if: file < 200 lines, OR you're rewriting it wholesale.
- Max 3 files open per task before you must state a hypothesis.
- Never read `package-lock.json`, `*.min.js`, `dist/`, `build/`, generated files, or lockfiles.
- Never re-read a file already in context this session.

## Structure first, content second

- `rg --files -g '*.ts' | head -50` beats reading a directory.
- `rg "^(export |class |def |func )" file.ts` gives you the shape in 10 lines.
- Follow imports only when the call actually crosses the boundary.

## Output

- Quote the 3–10 lines that matter, not the surrounding function.
- Cite `path:line` instead of pasting.
- Edits as targeted replacements. Never re-emit an unchanged file.

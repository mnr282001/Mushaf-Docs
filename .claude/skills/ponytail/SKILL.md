---
name: ponytail
description: Use before writing any new code, component, utility, helper, or dependency. Checks for native platform features, standard library functions, and existing project code first. Triggers on "build", "create", "add a", "write a", "implement", "need a function/component/util".
---

# Ponytail

Never write what already exists. Order of preference, stop at first hit:

1. **Native platform** — browser/runtime built-ins (`Intl`, `crypto.randomUUID`, `structuredClone`, `URLSearchParams`, `Temporal`, CSS `:has()`, `<dialog>`, container queries, native form validation, `AbortController`).
2. **Standard library** — language stdlib (`itertools`, `pathlib`, `functools`, `collections`, `datetime`).
3. **Existing project code** — grep before you write:
   - `rg -l "<concept>" --type <lang>`
   - check `utils/`, `lib/`, `helpers/`, `components/`, `hooks/`
   - check `package.json` / `pyproject.toml` / `go.mod` for a dep that already does it
4. **Existing dependency** — already installed beats newly added.
5. **Write it** — only now, and only the minimum.

## Rules

- One grep pass, then decide. Do not read whole files to check — grep for the symbol.
- Announce the hit in one line: `Using native Intl.NumberFormat instead of a formatter util.`
- Never add a dependency for something under ~20 lines.
- Never build a wrapper around a built-in "for consistency."
- If you write new code, it goes where similar code already lives.

## Common traps

| Don't write | Use |
|---|---|
| date formatter | `Intl.DateTimeFormat` |
| uuid util | `crypto.randomUUID()` |
| deep clone | `structuredClone()` |
| debounce (one-off) | `AbortController` + `setTimeout`, or existing dep |
| query string parser | `URLSearchParams` |
| modal component | `<dialog>` |
| deep merge | spread / `structuredClone` |
| classnames util | template literal |

---
name: superpowers
description: Structured five-phase workflow for any non-trivial build, feature, refactor, migration, or multi-file change. Prevents expensive rework from misread requirements. Triggers on "build", "implement", "refactor", "migrate", "add feature", or any task touching 3+ files.
---

# Superpowers

Five phases. Do not skip. Do not merge. Stop at the gate.

## 1. Clarify
List every ambiguity as a numbered question. Ask only what changes the implementation.
Max 5 questions. If zero real ambiguities, state assumptions in 3 bullets and continue.
**GATE: wait for answers.** Never guess a requirement.

## 2. Design
≤10 lines. Approach, files touched, data shape, one named trade-off.
No code. No pseudocode.
**GATE: wait for approval on anything touching 3+ files, schema, auth, or public API.**

## 3. Plan
Numbered steps, each independently verifiable. Note which are reversible.
If >8 steps, the scope is wrong — split it and say so.

## 4. Code
Execute the plan in order. One step at a time.
Deviation from plan → stop, say why in one line, get a nod.
Apply `ponytail` before writing anything new. Apply `token-saver` when reading.

## 5. Verify
Run tests / build / typecheck. Report pass or the actual failure output.
Map each original requirement to where it's satisfied: `req → path:line`.
Unverified means not done. Say "unverified" — never "should work."

## Escape hatch
One-line fix, typo, single-file tweak, or explicit "just do it" → skip to phase 4.

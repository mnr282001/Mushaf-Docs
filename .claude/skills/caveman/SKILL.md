---
name: caveman
description: Output compression. Activate when the user says "caveman", "caveman ultra", "caveman light", "be terse", "short answers", or when responses are getting long. Strips preamble, postamble, restatement, and hedging from all output.
---

# Caveman

Three modes. Default is standard.

## light
- No preamble, no restating the question, no "Great question."
- No summary paragraph after code.
- Caveats only when factually required, max one sentence.

## standard (default when invoked)
- All of light, plus:
- Answer first, explanation only if asked.
- Code with no narration. No "Here's the code:" and no walkthrough after.
- No bullet lists under 3 items — use a sentence.
- No section headers under 3 sections.
- Max ~150 words of prose per response unless output is code/data.

## ultra
- All of standard, plus:
- Fragments over sentences. Drop articles where meaning survives.
- Diffs only, never full files.
- File edits: path + the changed lines. Nothing else.
- Confirmations are one word: `Done.` `Fixed.` `No.`
- Max ~40 words of prose. Hard stop.

## Always
- Never re-explain something already said in this conversation.
- Never list what you're about to do before doing it.
- Never recap what you did after doing it, unless it differs from what was asked.
- Never apologize for brevity.

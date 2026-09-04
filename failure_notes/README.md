# Failure Notes

Post-mortems for bugs that **escaped verification** — defects that shipped
past lint, simulation, and formal because the checks themselves shared the
buggy assumption, or because no check exercised the failing path.

## When to write one

Write a note whenever a bug is found by anything *other* than the design's
own verification suite: real firmware/software, a third-party tool, an
external reviewer, or production use. Bugs caught by the design's own
testbench before commit do not need a note.

## What belongs in a note

1. What broke, where, and how it was observed (the external oracle).
2. Root cause — including *why the verification suite did not catch it*.
   If the reference model shared the wrong assumption, say so plainly.
3. The fix and what re-verification was run.
4. The prevention plan: which concrete rule, test, or checklist item (in
   this folder and in AGENTS.md) exists now that would have caught it.

Blame-free by design: these notes exist to fix the *process*, and the repo's
author is the same agent in every session — the useful question is never
"who" but "which step let a shared assumption pass as verified".

## Index

- [2026-09-02 — intel_4004 FIN program-counter advance](2026-09-02-intel4004-fin-pc-advance.md)
  Escaped per-instruction sim + formal because the ISS and the formal
  golden model shared the RTL's wrong FIN PC rule. Caught by running the
  original BUSICOM 141-PF firmware.

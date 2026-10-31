## What this records

A xezim miscompile that affects testbench oracles: a function that bit-selects a packed **formal whose range does not start at zero** can return `x`, or the wrong bit, for a subset of inputs.

Found while debugging `design/ttl_74xx` (see PR #91). The reproducer has no DUT — two functions implement the identical predicate and are compared exhaustively.

```
# xezim 0.11.3 (058f2bba)
nonzero_formal_select: 43 mismatches over 65536 vectors

# Verilator 5.052, same file
nonzero_formal_select: 0 mismatches over 65536 vectors
```

## Why it belongs in `overview.md`

The "Observed Discrepancies" section already carries a `mos_6567` entry for **function ports with non-zero-based ranges returning `X`** in 0.11.0, which was closed out as nondeterministic after it failed to re-trigger: *"could not re-trigger on either version ... so the original X was nondeterministic"*.

That conclusion was about that replay, not about the class. This case is the same class and it is deterministic — same 43 mismatches on every run, on a file with no DUT and no scheduling to vary. So the new entry is added, and the `mos_6567` entry now points at it and notes that its zero-based workaround is evidenced rather than merely cautious.

## What was ruled out, by running it

Each of these produces an identical 43-failure result:

| Toggle | Result |
|---|---|
| `XEZIM_JIT=0` / `=1` / unset | 43 |
| `XEZIM_NO_CACHE=1` | 43 |
| `--wave` (forces loops onto the slower AST path) | 43 |
| with / without `--sv2017` | 43 |

And the evasions that work: copy the formal into a `[11:0]` local and index `b[i-1]` → 0 mismatches; use a mask form → 0; declare the formal `[11:0]` and index `bb[i-1]` → 0. Hence the workaround line: declare function ports zero-based.

## Version re-check

0.11.3 **is** the latest release, so the repository pin is already current. I additionally built `main` at `0fca605f` (154 commits past the tag, 2026-10-29) and re-ran the reproducer: **still 43 mismatches**. Three of those 154 commits are about giving call actuals the callee formal's width, which is the right area, but the defect survives. The Dockerfile pin is therefore left at the 0.11.3 release rather than moved onto an unreleased commit that does not fix it.

## Verification

The documented command in the doc was run from the repository root:

```
xezim --simulate --sv2017 -s minimal_repro --max-time 500ms docs/xezim/repro/nonzero_formal_select.sv
```

and reproduces 43 mismatches here, with Verilator reporting 0 on the same file.

## Notes

- The reproducer file is LF in the repository, matching the other sources.
- I did not add a line to `docs/xezim/README.md`; the overview links the reproducer directly.
- Upstream issue filed 2026-10-29: https://github.com/aionhw/xezim/issues/650 — same reproducer, same ruled-out matrix.


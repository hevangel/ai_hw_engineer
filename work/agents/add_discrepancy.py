#!/usr/bin/env python3
"""Insert the 0.11.3 non-zero-based-formal discrepancy into the xezim overview."""
from pathlib import Path

path = Path("worktree/xezim-nonzero-formal/docs/xezim/overview.md")
text = path.read_text(encoding="utf-8", newline="")

old = (
    "  25722, so the original X was nondeterministic (scheduling-dependent) in\n"
    "  0.11.0. The zero-based workaround stays because fixed behavior is not\n"
    "  demonstrated.\n"
)

new = (
    "  25722, so the original X was nondeterministic (scheduling-dependent) in\n"
    "  0.11.0. That conclusion is about *that replay*, not about the class: the\n"
    "  same defect does reproduce deterministically on 0.11.3 in a simpler shape,\n"
    "  recorded below. The zero-based workaround stays.\n"
    "- **0.11.3, bit-select of a non-zero-based function formal** (found 2026-10-28\n"
    "  in `design/ttl_74xx`, minimised 2026-10-29): an `automatic` function with\n"
    "  `input logic [12:1] a` that evaluates `a[i]` for `i` in 1..12 inside a loop\n"
    "  can return `x`, or the wrong bit, for a small subset of inputs. The\n"
    "  reproducer in [repro/nonzero_formal_select.sv](repro/nonzero_formal_select.sv)\n"
    "  has no DUT — two functions implement the identical predicate and are\n"
    "  compared exhaustively — and reports **43 mismatches over 65536 vectors**,\n"
    "  while Verilator 5.052 reports **0** on the same file. The failing set sits\n"
    "  on the `P`/`P+1` boundary (32 `x`, 11 wrong `0`/`1`). Ruled out by running,\n"
    "  each with an identical 43-failure result: the Cranelift JIT (`XEZIM_JIT=0`\n"
    "  and `=1`), the elaboration cache (`XEZIM_NO_CACHE=1`), the compiled-vs-AST\n"
    "  split (`--wave`) and the language mode. Copying the formal into a `[11:0]`\n"
    "  local and indexing `b[i-1]`, or using the mask form, gives 0 mismatches, and\n"
    "  an `[11:0]` formal with `bb[i-1]` is clean too. Workaround: **declare\n"
    "  function ports zero-based**, as already required by the `mos_6567` entry\n"
    "  above. **Re-checked 2026-10-29 on main `0fca605f`**, 154 commits past the\n"
    "  0.11.3 tag: unchanged, still 43. This is the first deterministic\n"
    "  reproduction of the `mos_6567` class, so that entry's zero-based workaround\n"
    "  is now evidenced rather than merely cautious.\n"
)

old_crlf = old.replace("\n", "\r\n")
new_crlf = new.replace("\n", "\r\n")

if text.count(old_crlf) != 1:
    raise SystemExit(f"anchor found {text.count(old_crlf)} times; aborting")
text = text.replace(old_crlf, new_crlf)
path.write_text(text, encoding="utf-8", newline="")
print("inserted; file now", len(text), "bytes")

# 2026-10-23 — motorola_6800: subtract carry and 4x/5x accumulator select
# escaped the self-written oracle

## Summary

Two semantic bugs in the MC6800 design passed the entire self-written
verification stack (independent Python ISS + 1951-record full-ISA vector
replay + final-memory compare) and were caught only by the third-party
hakanrw/mc6800 test programs:

1. **Subtract carry polarity.** RTL and ISS both computed the
   subtract-family carry as NOT-borrow (the 6502 convention: equal
   operands → C=1). The M6800 Programming Reference Manual (SUB, A-66)
   defines C = "set if the absolute value of the contents of memory are
   larger than the absolute value of the accumulator" — i.e. C **is the
   borrow**: equal operands clear C. Both models shared the misreading,
   so the vector replay (which compares RTL against the ISS) could never
   see it; `sub.asm` fails its first test (expects C=0 after `01-01`).
2. **4x/5x accumulator select bit.** The inherent accumulator RMW ops
   (NEGA=40..CLRB=5F) were decoded with the accumulator selected from
   bit 6 (the rows 8-F convention). The 4x/5x discriminator is **bit 4**
   (0x4x = ACCA, 0x5x = ACCB). With bit 6 both 4x and 5x selected ACCB,
   so `NEGA` modified B. `neg.asm` stores the negated value and
   immediately exposes the wrong accumulator.

## Root cause

Both bugs are shared misreadings between the RTL and the reference model
written by the same author from the same (mis)reading of the manual —
exactly the per-instruction-agreement blind spot the assumption-ledger
rules exist for. The 6502's inverted SBC-carry convention contaminated
the 6800 model; the rows 8-F bit-6 pattern was over-generalized to rows
4/5.

## Fix

- RTL + ISS: subtract-family C = borrow (`f_sub8` bit 8 taken directly;
  Python `sub()` returns `c = 1 if t < 0 else 0`).
- RTL + ISS: 4x/5x inherent RMW accumulator = `~d[4]`.
- Spec updated with the C-is-borrow rule and an explicit note that it
  differs from the 6502 convention.

## Process changes

- The third-party suite (`run_software.sh`, 50 vendored hakanrw/mc6800
  programs) is now a mandatory gate in `run_all.sh`, with the ISS-vs-RTL
  result-window comparison as the pass rule.
- Lesson recorded for the follow-on 6809/68000 designs: never port flag
  conventions across ISA families, and check the primary source for every
  per-row encoding pattern instead of generalizing from an adjacent row
  group.

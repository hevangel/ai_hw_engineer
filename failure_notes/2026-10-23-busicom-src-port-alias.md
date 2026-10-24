# Busicom 141-PF SRC port-select "mod 5" alias had no hardware basis

- **Date found:** 2026-10-23
- **Found by:** external review of the repo (GitHub issue #57), not by any
  verification of this design
- **Fixed in:** this change set (board RTL, spec, report)
- **Design touched:** system/busicom_141pf (board RTL), spec, report

## What happened

The board RTL contained a "ROM-port select alias translator": a snooper that
rewrote every SRC X2 bus nibble greater than 4 to `nibble mod 5` before the
five 4001s saw it. The code comment justified it with "trace shows it
selects nibbles 0/1/2/4/5/7, where 5 aliases to port 0 (shifter clocks) and
7 aliases to port 2 (drum index / paper button)". The 2026-09-27 report even
listed "port nibble aliasing (SRC nibble mod 5)" as a contract "confirmed"
by the Kintli disassembly — which it is not: nothing in the Kintli
disassembly, the 4004.com replica materials, or any other source describes
such a decode. It was an assumption introduced during board bring-up and
never validated against an external artifact, in exactly the shape the
2026-09-02 FIN post-mortem's assumption-ledger rule (prevention plan item 3)
was written to catch.

## Why it matters

A wrong board-level decode is invisible to per-chip verification (the 4001
design verifies exact full-nibble compare, correctly). If the alias had been
*load-bearing*, the headline result — the original firmware reproducing the
scanned manual's 42 examples — could have been passing because board RTL and
the independent oracle shared an emulator-derived convention rather than
because the RTL matches the machine.

## What the trace actually shows

Reading the Kintli disassembly (`spec/reference/Busicom-141PF-Calculator_asm_rel-1-0-1.txt`)
site by site, every functionally-relevant ROM-port operation issues the
exact strapped chip number in the SRC X2 nibble:

| Site | Sequence | X2 nibble | Port |
|---|---|---|---|
| $064-$069 (`src 4<` + `wrr` ×2) | shifter clocking, R8 = 0 after `fim 4< $00`/`fim 4< $07` and during printing (`xch 8` clears R8 at $255) | 0 | ROM0 (shifter clocks/data) |
| $02e/$033 (`src 3<` + `rdr`), $0b8-$0c0 (`fim 3< $18` = R6=1, `src 3<` + `rdr`) | decimal-point/rounding switch and keyboard-column reads | 1 | ROM1 (keyboard matrix) |
| $06b-$06e (`fim 1< $20` = R2=2, `src 1<` + `rdr`) | drum index read in the sector-sync subroutine | 2 | ROM2 (drum index) |
| $01e-$020 (`inc 6` → R6 = 1+1, `src 3<` + `rdr`) | paper-advance button read in the main loop | 2 | ROM2 (paper button) |

SRC nibbles outside 0-2 do occur, but only on selects that are harmless
either way: the WRR at $243 goes out with the leftover R8 = 1 (ROM1, whose
port the host re-drives every tick), and RAM-side `src` selects with pointer
nibbles 4-7 (RAM chips 1 register 0-3) are ignored by the 4001s because
OPR = 1110 data transfers do not match the snooped WRR/RDR opcodes. On the
real board those values simply select no ROM — which is also how the
independent V. Ilmer reference behaves: its 4001 model
(`chips/src/mcs4/rom4001.rs` at the pinned revision) compares the **whole
SRC high nibble** against the chip's page mask with no aliasing; the only
`% 5` in his emulator is on the *fetch* address chip index ("Evaluation Kit
fails without this wrapping", `chips/src/mcs4/mod.rs`), which the MCS-4
designs model via genuine 4001 page strapping, not board translation.

The "nibbles 4/5/7 in the trace" that motivated the translator were RAM-side
SRC selects passing under CM-ROM, misread as ROM-port activity; the
translator remapped them (inertly, since no WRR/RDR followed) and happened
to map 5→0/7→2 in a way that looked intentional.

## Fix

- Removed the translator from `src/busicom_141pf.sv`; all chips now see the
  raw bus. The ROM-port addressing contract (full-nibble compare against
  CHIP_NO straps 0-4; firmware uses 0/1/2) is documented in the board RTL
  and `spec/spec.md` section 3.1.
- Re-verified: board bring-up self-check and the full 42-example manual
  regression (`--profile recovered-rom`) pass unchanged on Verilator, so the
  translator was functionally inert for this firmware and its removal is
  behavior-preserving.

## Prevention applied

1. The assumption-ledger rule now has a concrete worked example outside the
   4004 core: board-level integration assumptions need the same
   `ASSUMPTION:`/external-artifact treatment as ISA semantics.
2. When a trace motivates a decode, name the disassembly *addresses* that
   prove it, and cross-check the independent oracle's actual decode before
   believing shared behavior (the oracle's fetch `% 5` was one grep away).

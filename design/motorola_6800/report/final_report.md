# Final Design Report — Motorola MC6800

## 1. Executive Summary

The MC6800 recreation is complete and signed off at the functional-bus
contract level: the full documented instruction set (72 instructions,
197 valid machine codes) passes an independent-oracle vector regression,
all 50 vendored third-party self-checking test programs, formal
bmc/prove/cover, `-Wall` lint and generic Yosys synthesis. Cycle counts
and the original two-phase pin protocol are out of contract (documented
in the spec).

## 2. Verification results

| Gate | Result |
|------|--------|
| ISA vector replay (`run_sim.sh`) | **PASS** — 1951/1951 instruction-boundary checks equal the ISS, 0 memory diffs, 197/197 documented opcodes executed |
| Third-party software (`run_software.sh`) | **PASS** — 50/50 hakanrw/mc6800 programs, result windows byte-identical to the oracle |
| Formal (`run_formal.sh`) | **PASS** — bmc (depth 40), prove (pdr), cover (smtbmc z3) all DONE (PASS) |
| Lint (`run_lint.sh`) | **PASS** — `verilator --lint-only -Wall` on RTL and TB |
| Synthesis (`run_synth.sh`) | **PASS** — Yosys generic flow, `hierarchy -check` clean |

## 3. Escaped defects found by the third-party gate

Two bugs passed the full self-written stack and were caught only by the
vendored hakanrw/mc6800 programs (post-mortem:
`failure_notes/2026-10-23-motorola6800-subtract-carry-and-acc-select.md`):

1. Subtract carry polarity: the 6800's C is the **borrow** (PRM SUB,
   A-66), not the 6502's NOT-borrow; both the RTL and the ISS shared the
   misreading until `sub.asm` failed its first test.
2. The 4x/5x inherent-RMW accumulator select uses **bit 4** (0x4x = ACCA,
   0x5x = ACCB), not bit 6 as in rows 8-F; `NEGA` modified B.

Both are fixed in RTL, ISS and spec; the third-party suite is now a
mandatory gate in `run_all.sh`.

## 4. Contract notes

- The design implements the documented ISA on a functional transaction
  bus (one transfer per clock). Interrupt sampling happens at instruction
  boundaries; the stacked CC keeps the pre-interrupt I and the live I is
  set after the push (PRM 3.3.4), verified by the nested-interrupt
  scenarios.
- Undocumented opcodes (59 of 256 codes) execute as mode-length no-ops
  (spec assumption ledger).
- Cycle counts, DBE/TSC bus handshakes and electrical timing are out of
  contract for this revision.

## 5. Open items

- Original-hardware-software regression (MIKBUG with a modeled 6850 ACIA,
  or the Dendai Tiny BASIC) — the third-party suite is the current
  software gate.
- Pin-accurate two-phase clock timing model as a separate physical-bus
  variant (precedent: `mos_6502_cycle`).

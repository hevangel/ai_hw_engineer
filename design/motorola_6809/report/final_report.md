# Final Design Report — Motorola MC6809

## 1. Executive Summary

The MC6809 recreation is complete and signed off at the functional-bus
contract level: the full documented instruction set passes both
reyco2000 third-party self-checking programs (functional + interrupt),
formal bmc/prove/cover, `-Wall` lint and generic Yosys synthesis. Cycle
counts and pin protocol are out of contract (documented in the spec).

## 2. Verification results

| Gate | Result |
|------|--------|
| Functional suite (`run_sim.sh` 1/2) | **PASS** — 6809_functional_test, DEV_EXIT=0, 533,184 bus cycles |
| Interrupt suite (`run_sim.sh` 2/2) | **PASS** — 6809_interrupt_test, DEV_EXIT=0, 7,415 bus cycles |
| Formal (`run_formal.sh`) | **PASS** — bmc (depth 40), prove (pdr, unbounded), cover (smtbmc z3) all DONE (PASS) |
| Lint (`run_lint.sh`) | **PASS** |
| Synthesis (`run_synth.sh`) | **PASS** — Yosys generic flow |

## 3. Defects found and fixed during third-party verification

The reyco2000 suite (validated against real hardware) caught, in order:

1. **Reset vector location**: FFFE, not the FFFC slot this design first
   assumed (both MAME and the suite's ROM tables confirm FFFE; FFF0/1
   reserved).
2. **Vector map shift**: all seven vectors were one slot low (SWI3 at
   FFF2, not FFF0). Caught by the interrupt test's unexpected-interrupt
   traps.
3. **Missing decode entries**: page-1 STX (9F/AF/BF), LDD (CC/DC/FC/EC),
   RTS (39), the 4x/5x accumulator RMW block, and MUL at **$3D** (the
   $01 slot this design first used is a 6800-ism).
4. **Branch condition table off by the BRN gap**: the cond index is
   {1, opcode[3:0]} — BRA=10 — not the raw $14-$1F opcodes.
5. **Push/pull byte order**: 16-bit registers sit big-endian on the
   stack; pulls take the high byte first (proven by `pshs d`/`puls pc`
   round-trip with A=$17, B=$8D → PC=$178D).
6. **STA clears V** (and sets N/Z from the stored byte) — the 6800/6809
   store-flag rule this design initially applied only to 16-bit stores.
7. **ADD overflow formula**: (x^r)&(y^r), not the subtract-form
   (x^y)&(x^r); $00+$80 must clear V. Fixed in the 6800 RTL and ISS too
   (shared root cause; the hakanrw 6800 suite had no discriminating
   case).
8. **ADC half-carry ordering**: H must be computed from the incoming C
   before C is overwritten (blocking-assignment order bug).
9. **SBC subtracts C directly** (A − M − C), not !C — shared with the
   6800 models; fixed everywhere.
10. **6809 shift V rules differ from the 6800**: LSR and ROR clear V
    (suite-derived ground truth); ASL/ASR/ROL keep V = N⊕C.
11. **TST preserves C** on the 6809 (the 6800 TST also preserves C; this
    design's shared f_rmw cleared it).
12. **SWI sets live I and F; SWI2/SWI3 set no live masks** (suite
    comment + flag-capture checks).
13. **Live E mirrors the frame**: SWI/IRQ/CWAI set live E; FIRQ clears
    it (handler `tfr cc,a` checks).
14. **CWAI push used pull order** (pq_push left 0 by an earlier PULS) —
    formal-found frame corruption; fixed.
15. **PULS/PULU with an empty mask** livelocked the queue —
    formal-found; now a no-op, matching hardware.

Items 1-3 and 7-9 are exactly the escaped-defect class the repo's
real-software rule exists for: a self-written oracle shares the author's
misreadings, while hardware-validated software does not.

## 4. Contract notes

- Functional transaction bus (one transfer per clock); interrupt sampling
  at instruction boundaries; NMI edge-latched and disarmed until the
  first LDS/LEAS-style S load after reset.
- DEV device registers ($FF00-$FF0F) are a test-harness convention of
  the reyco2000 suite, implemented in the testbench only.

## 5. Open items

- Cycle-count model and a physical-bus variant (precedent:
  `mos_6502_cycle`).
- HD6309 emulation-mode coverage (the suite also provides 6309 tests).

# Am29332 final report

## Result

All verification gates pass. The member is complete and awaiting review on
PR #259.

| Gate | Command | Result |
| --- | --- | --- |
| Transcription guard | `python3 scripts/generate_oracle.py --check-table` | PASS — every worked example from the manual (Appendix A 1-13 with nibble-carry expectations, Appendix B multiply and divide traces, Chapter 2 field-operation examples, PRIOR example) matches the model |
| Vector generation | `python3 scripts/generate_oracle.py` | 17,537 vectors; all 36 algorithm sequences pass independent arithmetic assertions (true products; true truncating quotients/remainders) |
| Lint | `verilator --lint-only -Wall --top-module amd_am29332` | PASS |
| Lockstep simulation | `sh scripts/run_sim.sh` | PASS — 17,537 vectors, 105,202 output checks, 0 failures |
| Formal bmc | `sby -f formal/amd_am29332.sby bmc` (depth 8, smtbmc z3) | PASS (~16 min solver time) |
| Formal prove | `sby -f formal/amd_am29332.sby prove` (smtbmc z3, k-induction, depth 8) | PASS — successful proof by k-induction |
| Formal cover | `sby -f formal/amd_am29332.sby cover` | PASS — all class reachability cover points hit |
| Synthesis | `sh scripts/run_synth.sh` (yosys `check -assert`) | PASS — 16,894 cells / 64 FF bits |

## What is verified

- Every defined opcode (124) at every byte width, driven through the full
  pin interface including instruction-side selects (I8/I7), macro/micro
  carry-link selection, BOROW polarity, RS/HOLD/SLAVE output muxing, parity
  generation and check, and the master/slave diagnostic comparators.
- The manual's worked examples, end to end: 65h × 48h = 1C68h (multiply),
  75h / 02h → Q = 3Ah remainder 01h with N=1 at UDIVLAST (divide), BCD
  examples 1-13 with exact nibble-carry patterns, the Chapter 2 field-op
  examples with p>0/w=0 and p<0/w=0 forms, and the PRIOR-A example.
- Algorithm sequences with register feedback (the B input of each
  multiply/divide step is the previous row's Y, QUOCORR's B is the quotient
  register): at byte widths 1/2/4, checked against true arithmetic.
- Sequential contracts formally proven: HOLD freeze, LDSTAT write-mask
  (writable bits only; read-only bits re-derive), LOADQ write-mask,
  PASS-STAT/PASS-Q state neutrality, logical/N-bit/bit/field/mask classes
  never touching C/V/L/M/S or the nibble-carry byte, and the read-only
  relational bits always equaling their definitions.

## Known limits

- The three-state Y pad itself is external to the model (the series
  `y_o/y_oe_o` pad-split convention); slave/master comparison is verified
  through the `*_ext` wire inputs and the mserr comparator, not through
  tri-state resolution.
- Master-mode buffer-open diagnostic (comparing the driven pad against the
  internal value) cannot be distinguished from a correct drive in a digital
  model; it is exercised through the same comparator path as slave mode.
- No AC timing; the model is cycle-accurate at the CP interface.
- Undefined opcodes 1E/1F/4C/4D: outputs unspecified by the manual; the
  model passes B and updates nothing (spec ledger).

## Notes for reviewers

- The divide-step semantics were derived by rule sweeps against true
  division in addition to the printed trace: S ← F[w-1] (w-bit remainder
  sign), quotient bit ← ¬F[w] (extended-result sign), REMCORR gated on
  Z⊕N⊕S, FIRST's Y written back into the remainder register. The trace
  alone under-determines these; the sweeps at widths 8/16/32 pinned them.
- STATUS<15:13>/bit 23 are modeled as combinational functions of the
  stored flags (bit 13 also of the current BOROW pin) with no storage
  cells, per EXTBIT-STAT note 2 and PASS-STAT note 1; every readout
  (PASS-STAT, LDSTAT unselected bytes, SETBIT/RSTBIT-STAT Y, EXTBIT-STAT)
  presents the live values. This is an assumption-ledger entry, not a
  directly quoted statement.
- Verilator 5.052 mis-compiles an inline `5'(~y[4*i +: 4])` select inside a
  function loop (verified standalone); the nibble functions route nibble
  operands through explicit temporaries with a comment pointing at this.
- The yosys aig engine (abc pdr) rejected this design's input-port structure
  ("73 undriven bits … 'x' or 'z' bits") even after `memory_map` +
  `setundef -zero`, while smtbmc handles the same design; the prove task
  therefore uses smtbmc k-induction. Yosys also requires constant
  procedural loop bounds (PRIOR, nibble loops) and rejects out-of-range
  select padding (the EXTF-AB/BA 64-bit rotate uses a doubled-register
  trick with a single in-range shift).
- BMC/cover were re-run on the final RTL after the PRIOR count-base and
  EXTF-rotate fixes; the induction prove covers the assertion set on the
  same RTL revision.

# Am29331 verification report

Verified digital contract: all 64 manufacturer instructions across the four
classes with their condition/counter qualifications, sixteen-bit state,
native rising-edge updates, 33-word stack over a modulo-64 pointer
(including the documented single-wrap overflow and A-FULL underflow
behavior), synchronous active-low reset, hold freeze, interrupt
accept/push/return sequence, FC/C̄IN trap selection, breakpoint comparator
and master/slave ERROR checking. No A-revision functional delta exists: the
documented Am29331A difference is a 15% timing grade only.

## Reproducible results

Toolchain ai-hw-engineer:latest: Verilator 5.052, Yosys 0.69,
SymbiYosys/Z3/ABC. Run `sh design/amd_am29xxx/members/am29331/scripts/run_all.sh`.

- Verilator `--lint-only -Wall`: clean, no suppressions.
- Manufacturer CSV generation check: passed. The oracle was transcribed
  from visually inspected page images of the 1988 data book Tables 1/2
  (cross-checked against the 1985 handbook) before RTL; the
  `--check-table` guard caught a stale formal-oracle table during
  bring-up, which is exactly the drift it exists for.
- 81,960 independent transition vectors: 49,152 systematic combinations
  over all 64 opcodes × condition polarity × C̄IN × FC × OED × counter
  {1, 2} × pointer {0, 1, 5, 27, 28, 33} × interrupt request/enable
  combinations, 40 reset/hold cases, plus 32,768 deterministic random
  full-space vectors. Every vector establishes state through native
  instructions (reset, GOTO D, PUSH D, LOAD D, SET/CLEAR), checks pre-edge
  outputs, applies one edge, and reads PC, SP, A-FULL, comparator and top
  of stack back through pins (CONTINUE/C̄IN stall, POP D with OED, PUSH C).
  2,390,599 checks passed; undefined-value cases (empty-TOS reads, deep
  overflow) mask value checks while keeping pointer/enable checks.
- 196,749 historical microcode words: original AMD Figure 3 constructs
  (FOR/END FOR with N=0→65,536 semantics, REPEAT/UNTIL and WHILE/END
  WHILE through LOOP with BRCC_S/BRNC_S/XTCC_D/XTNC_D/BRA_S, CASE through
  PUSH D + GOTO M for all four multiway sets, double nested IF) and the
  Figures 4–7 interrupt and trap cycles, with exact executed/next
  addresses, INTA timing, deferred return-address push and
  re-execution-after-trap. Unmapped execution is fatal; no padding
  landings.
- Stack envelope: 33-entry fill and LIFO drain through RET, then the
  documented overflow push at SP=33 overwriting the bottom entry, with
  A-FULL and pointer checks at every step. 224,941 stack-word readbacks
  in total across the suite.
- Master/slave: driven-vs-observed contention on D and Y as master,
  clean-run zero, slave mismatch detection for Y, D, INTA, A-FULL and
  EQUAL individually, hold silencing ERROR, and slave interrupt
  acceptance with INTA comparison.
- Formal BMC depth 16 (smtbmc z3): PASS. Unbounded ABC PDR (prove): PASS.
  Cover (smtbmc z3): PASS — 74 cover traces reached with zero unreached
  statements: all 64 opcode covers plus boundary covers (pointer
  27/28/33/63, overflow push, underflow pop, CALL TOS exchange, POP D TOS
  output, SET match, RESET SP, each multiway set, DJMP_S exit, forced
  stall) are reachable from unconstrained initial state. The property
  layer also asserts RTL-decode equality (stack/counter/comparator action
  and D-mux match the CSV table every cycle). Two verification-infra
  reworks were needed, not suppressions: variable-indexed writes and
  reads on the original packed 2-D stack array lowered to `$shiftx`/x-z
  padding that AIGER rejects, so the stack became a true unpacked memory
  (variable indices then lower to read/write ports) and the property
  layer replaced `$past` of memory reads with a per-slot shadow register.
- Synthesis: 2,560 cells, 600 register bits (528 stack + 64
  PC/IRAR/C/R + 6 SP + enables), zero latches; Yosys `check -assert`
  reports zero problems.

The initial ABC conversion reported the 12 undriven `d_i` bits as `$anyseq`
(as expected for an unconnected bidirectional input pair) and initially
failed on x/z bits produced by variable-indexed access into the packed
stack array; that RTL structure was replaced with an unpacked memory and a
decoded write-enable, not suppressed. The full gate
(`scripts/run_all.sh`: table check, lint, bmc/prove/cover, simulation,
synthesis) passes end-to-end in the repository toolchain image.

## Limits

Electrical setup/hold/propagation (Tables A/B/C nanosecond limits), the
Am29331A timing grade and power sequencing are not modeled. Stack slot
contents beyond the first documented overflow wrap and reads through a
stale or empty TOS are outside the contract and masked in verification;
the concurrent stack operation in the automatic-interrupt-push cycle is a
documented model choice (hardware push wins), not datasheet behavior. The
microcode regressions realize AMD's documented control-construct examples,
not a recovered application ROM. Introduction-year evidence establishes
advanced information by 1985 and a December 1987 final datasheet; the
first production/shipment date remains unestablished.

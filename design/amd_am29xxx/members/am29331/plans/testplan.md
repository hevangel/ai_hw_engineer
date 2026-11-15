# Am29331 test plan

- Transcription check: `generate_oracle.py --check-table` regenerates the
  formal oracle from `references/instructions.csv` and asserts the
  committed `formal/table_oracle.svh` matches byte for byte.
- Transition matrix: 49,152 systematic vectors (64 opcodes × condition
  polarity × C̄IN × FC × OED × counter {1, 2} × pointer
  {0, 1, 5, 27, 28, 33} × interrupt request/enable combinations) plus
  32,768 deterministic random vectors over the full pin and state space
  and 40 reset/hold cases. Each vector establishes state through native
  instructions (RST, GOTO D, PUSH D, LOAD D, SET/CLEAR), checks pre-edge
  outputs, applies one edge, and reads PC, SP, A-FULL, comparator and the
  top of stack back through pins. Undefined-value cases (empty-TOS reads,
  deep overflow) keep pointer checks and mask value checks.
- Historical flows: Figure 3-2 FOR/END FOR with N=0, 1, 2, 5 and the
  N=0→65,536 semantics; Figure 3-1 REPEAT/UNTIL through LOOP with
  BRCC_S/BRNC_S at 0–2 passes plus immediate exit; WHILE/END WHILE through
  LOOP, XTCC_D/XTNC_D and BRA_S; Figure 3-3 CASE through PUSH D and GOTO M
  for all four multiway sets; Figure 3-4 nested IF for all four condition
  combinations; Figures 4–5 flat and nested interrupts with exact INTA,
  Y release, deferred push and return addresses; Figures 6–7 trap with
  FC/C̄IN/INTR, re-execution after the routine, and the INTR-less stall.
- Stack envelope: fill to 33 entries, drain through RET checking LIFO
  order, then the documented single-wrap overflow (push at SP=33
  overwrites the bottom entry) with A-FULL and pointer checks.
- Master/slave: driven-vs-observed contention as master on D and Y,
  clean-run zero, slave mismatch detection for Y, D, INTA, A-FULL and
  EQUAL individually, hold silencing ERROR, and slave interrupt
  acceptance with INTA comparison.
- Formal: BMC depth 16, unbounded ABC PDR and cover over the CSV-derived
  reference model — per-cycle output contract, per-edge state transitions
  with reset/hold/interrupt cases, 64 opcode covers plus boundary covers
  (pointer 27/28/33/63, overflow push, underflow pop, CALL TOS exchange,
  SET+EQUAL match, RESET SP, each multiway set, DJMP_S exit, forced stall).
- Synthesis: Yosys `synth; check -assert` with cell and register counts
  recorded; no latches.
- Gates: `scripts/run_all.sh` must pass lint, formal, simulation and
  synthesis in the repository toolchain.

# Implementation Plan — Motorola MC6809

## Scope

Full documented instruction set (page 1, page 2 $10, page 3 $11) on a
functional transaction bus: one bus transfer per `clk`. Registers A, B, D,
X, Y, U, S, DP, PC, CC (E F H I N Z V C); the full indexed postbyte set
including indirect forms; TFR/EXG; PSHS/PULS/PSHU/PULU; MUL; long
branches; three software interrupts; FIRQ short frames; CWAI; SYNC; RTI
with E-bit frame restore. Out of contract: pin protocol and per-opcode
cycle counts.

## Primary sources

- Motorola MC6809 data sheet / M6809 Programming Manual behavior as
  cross-checked against MAME's m6809 core and the reyco2000 suite's
  self-checking programs (hardware-validated).
- Vector map: FFF2 SWI3, FFF4 SWI2, FFF6 FIRQ, FFF8 IRQ, FFFA SWI,
  FFFC NMI, FFFE RESET (FFF0/1 reserved) — confirmed by both MAME and
  the reyco2000 ROM tables.
- Frame layout: CC, A, B, DP, X, Y, U/S, PC bottom-up; 16-bit registers
  big-endian on the stack (pulled high byte first); FIRQ stacks PC+CC
  with E=0 and sets live F and I; IRQ stacks everything (E=1) and sets I;
  SWI stacks everything (E=1) and sets I and F; SWI2/SWI3 stack
  everything and set NO masks; NMI is edge-latched, disarmed until the
  first LDS/LEAS-style S load after reset.

## Structure

Single module `motorola_6809.sv`: microsequenced FSM with prefix state,
indexed-postbyte evaluation, indirect pointer fetch, and a masked
push/pull queue engine (pbm_q walks the register mask; 16-bit registers
take two bytes, big-endian on the stack). Helper tasks carry the
per-instruction ALU/flag work; the sequencer arms use NBAs while tasks
mix blocking (registered-address computation) and NBA (queue-entry state)
writes, per the notes in the code.

## Verification plan

1. **Independent-oracle vector regression**: none written for this
   design — the reyco2000 suite fills the oracle role directly (its
   programs encode expected results and flags for every documented
   instruction × addressing mode, generated against real hardware).
2. **Third-party software gate**: reyco2000/6809_6309_code_tester
   6809_functional_test (all instructions, addressing modes, flags, stack
   frames; ~533K cycles) and 6809_interrupt_test (IRQ/FIRQ/NMI/SWI/SWI2/
   SWI3/CWAI/SYNC masking, frames, nesting; 7,415 cycles), vendored in
   `references/reyco2000_6809/`, run by `tb/tb_top.sv` with the suite's
   DEV device model ($FF00 lines, delayed line changes, cycle counter,
   $FF0F exit).
3. **Formal**: BMC/prove/cover — bus discipline, reset/vector behavior,
   frame addressing and byte order, JSR linkage byte order, queue-mask
   non-vanishing invariant, bounded progress; reset-stable assumption.
4. Lint under `verilator --lint-only -Wall` (RTL and TB); generic Yosys
   synthesis.

## Known deviations / open items

- Cycle counts and the 6809E early-bus-release variant are not modeled.
- Mixed blocking/NBA task writes are deliberately limited to registers
  with a single late-commit reader; yosys formal mis-lowers some blocking
  frame-entry writes, so the frame-entry writes use NBA (see
  start_frame/exec_imm8 comments).

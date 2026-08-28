# Implementation Plan: intel_4004

## Overview

Implement the Intel 4004 (MCS-4 CPU, first commercial microprocessor,
introduced November 15, 1971) as a single-clock, synthesizable functional
reconstruction per `spec/spec.md`. One module, `intel_4004`, containing the
full datapath, the 8-phase instruction-cycle sequencer, and the bus I/O
multiplexing.

## Architecture

Single module with three cooperating sections:

1. **Sequencer** — {cycle, phase} FSM. `phase` counts 0-7 (A1..X3); `cycle`
   is 1 or 2, set to 2 for JCN, FIM, FIN, JUN, JMS, ISZ (decoded from the
   cycle-1 word) and otherwise 1. `sync` is phase 0; `cm_rom` is phases 0-2.
2. **Fetch path** — 12-bit PC = stack[SP]. PC increments at A1 (the edge
   ending phase 0). OPR/OPA are latched at M1/M2. Second-cycle A1-A3 drive
   {R1, R0, PC[11:8]} when the cycle-1 word was FIN; otherwise the PC.
3. **Execution path** — all architectural state updates (PC/stack, ACC, CY,
   index registers, SRC pointer, CMD) are computed combinationally from
   latched state and the X3-sampled `data_i`, and committed on the single
   edge ending the instruction's final X3 (phase 7 of cycle 1 for one-cycle
   instructions, of cycle 2 for two-cycle ones). This one-commit-point
   structure keeps the transition function small enough for the formal
   equivalence proof (see formal_plan.md).

Supporting combinational blocks:

- **ALU** — a 5-bit {CY, ACC} adder covering ADD/SUB/ADM/SBM/IAC/DAC (the
  subtracts feed ~operand + CY, so one adder serves all six), plus the
  dedicated DAA correction and the KBP one-hot encoder.
- **RAM/ROM I/O mux** — `data_o` selection: PC/FIN-pointer nibble during
  A1-A3, SRC pair nibble at X2/X3, ACC for write ops at X2/X3. `data_oe`
  gates exactly those windows. `cm_ram` decodes CMD: line 0 when CMD = 0,
  line 1/2/3 from CMD bits 0/1/2, during X2-X3 of SRC and OPR = 1110
  (excluding WRR/RDR and reserved codes).
- **Index register file** — 16×4 logic array (no inferred memory).

## Implementation Steps

1. Parameter/localparam phase and opcode encodings; reset state.
2. Sequencer and bus statics (`sync`, `cm_rom`, phase output behavior).
3. Fetch path with A1 PC increment and OPR/OPA latches.
4. Decode: two-cycle detection, X3 commit mux for every opcode class.
5. RAM/ROM I/O bus driving and `cm_ram` decode.
6. `` `ifdef FORMAL `` structural assertions inline (FSM validity, output
   enables).
7. Lint, then simulation and formal per the plans.

## Risks

- **Page-straddle quirks** (JCN/JIN/FIN/ISZ at word 254-255): handled by
  construction via the A1-increment timing; covered by directed simulation
  at the 253-256 boundary.
- **Stack overflow at 4 nested JMS**: documented circular behavior; covered
  by directed test.
- **Subtract carry convention** (spec 5.7): SUB and SBM both add the
  inverted carry (`ACC + ~operand + ~CY`, CY = 1 = no borrow), per the
  manual's SBM equation and hardware-validated implementations; spec
  documents the interpretation.

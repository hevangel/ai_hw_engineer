# Final Design Report — Motorola MC68000 (work in progress)

## 1. Executive Summary

The MC68000 recreation is **in progress**, following the repo's
work-in-progress pattern (see intel_80286). The verification foundation
is complete: the full SingleStepTests 680x0 suite (1,000,060 vectors,
124 opcode files) is vendored and compiled into a replay-ready harness,
and the RTL skeleton (register file, USP/SSP banking, fetch/retire
handshake) is lint- and synthesis-clean. Instruction classes land
incrementally, each closing against its slice of the vectors.

## 2. Completed so far

| Item | Result |
|------|--------|
| Vector harness | **complete** — 1,000,060 tests compiled (142 MB stream + 74 MB final states + index); suite semantics validated (initial/final RAM deltas, opcode-word injection from the test name, exception vectors read from memory) |
| RTL skeleton | **complete** — lint clean (-Wall), Yosys generic synthesis clean |
| Documentation | spec/plan/testplan land the contract and landing order |

## 3. Open items (landing order)

1. MOVE group (4 files, ~80K vectors) — brings the full EA engine up.
2. ALU classes: ADD/SUB/CMP families, logic/immediates, quick forms,
   MOVEQ, single-operand ops, EXT/SWAP.
3. MUL/DIV; shifts/rotates (register + memory, ROX); bit ops; MOVEM;
   MOVEP; TAS.
4. Flow: Bcc/BSR/DBcc/Scc, JMP/JSR/RTS/RTR/RTE, LEA/PEA/LINK/UNLK, EXG.
5. Exceptions: privilege/illegal/A-line/F-line/divide-by-zero/CHK/
   TRAPV/TRAP/trace; two-word SSP frame; MOVE to/from CCR/SR/USP.
6. Formal properties on the sequencer, EA engine, and exception framing.

## 4. Contract notes

- Final architectural state per instruction (registers, SR, PC, memory
  bytes) is the verification contract; the prefetch queue, per-opcode
  cycle counts, and the suite's per-cycle `transactions` traces are out
  of contract.
- IPL is tied to no-interrupt; the suite does not exercise interrupt pin
  timing.

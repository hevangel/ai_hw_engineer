# Implementation Plan — Motorola MC68000 (work in progress)

## Scope

Full user ISA on a functional transaction bus, verified to final
architectural state against the SingleStepTests 680x0 suite (1,000,060
single-instruction vectors across 124 opcode files; fetched into
`references/singlesteptests_680x0/` by `scripts/fetch_vectors.py` —
~194 MB compressed, working-tree only, not committed). Out of contract:
prefetch queue, cycle counts, per-cycle transaction traces.

## Landing order (each step closes against the vectors)

1. **Harness** (complete): `scripts/make_68000_vectors.py` compiles all
   1M tests into `work/sim/m68k_{tests,index,final}.bin`; the C++
   testbench seeds/compares memory patches, pokes registers via
   `--public-flat-rw`, injects the opcode word at PC, runs to `done_o`,
   and reports per-opcode-file pass counts.
2. **Skeleton** (complete): register file, USP/SSP banking, fetch,
   retire handshake; lint/synth clean.
3. **MOVE group** (in progress): 4 opcode files, ~80K tests — all 14
   addressing modes exercise the EA engine end to end.
4. Integer/ALU classes: ADD/SUB/CMP families, logic + immediates,
   quick forms, MOVEQ, single-operand ops, EXT/SWAP.
5. MUL/DIV, shifts/rotates (both forms), bit ops, MOVEM, MOVEP, TAS.
6. Flow: Bcc/BSR/DBcc/Scc, JMP/JSR/RTS/RTR/RTE, LEA/PEA/LINK/UNLK, EXG.
7. Exceptions: privilege, illegal/A-line/F-line, divide-by-zero, CHK,
   TRAPV, TRAP, trace; two-word frame on the SSP; MOVE to/from
   CCR/SR/USP.

## Primary sources

- SingleStepTests 680x0 vectors (hardware-checked reference
  implementation; "conforms to all available documentation, official and
  third-party; passes all other published test sets").
- Motorola 68000 Programmer's Reference Manual for structure and flag
  definitions.
- Vector-map cross-check: `map/68000.official.json` in the suite.

## Known structural decisions

- EA evaluation is a microsequenced sub-FSM shared by all classes; the
  destination EA of two-address instructions is evaluated AFTER the
  source operand is read (68000 (An)+/-(An) ordering).
- The suite does not exercise interrupt pin timing; IPL is tied off.

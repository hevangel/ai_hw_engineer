# Coverage Report: Intel 4004

## Functional coverage evidence

The xezim regression (`scripts/run_sim.sh`) executes a directed program and a
fixed-seed random program against the CPU with behavioral 4001/4002 memory
models, comparing every architectural register at every instruction boundary
and every bus signal at every clock. The regression completes with zero
mismatches:

```text
4004 simulation result: 165778 cycles, 20192 instruction boundaries
Phase A boundaries: 12000 (46/46 instructions seen), Phase B boundaries: 8192
TEST PASSED
```

## Instruction coverage

All 46 defined instructions of the implemented repertoire execute and match
the reference model:

- Basic (16): NOP, JCN (all 16 condition codes, taken and not-taken), FIM,
  SRC, FIN, JIN, JUN, JMS, INC, ISZ (taken loop and skip paths), ADD, SUB,
  LD, XCH, BBL, LDM.
- RAM/ROM I/O (16): WRM, WMP, WRR, WPM, WR0-WR3, SBM, RDM, RDR, ADM, RD0-RD3
  — exercised across RAM banks 0-2 selected via DCL (including the
  multi-line command codes 3 and 7, with both models selecting the lowest
  active bank), and across ROM chips for WRR/RDR.
- Accumulator group (14): CLB, CLC, IAC, CMC, CMA, RAL, RAR, TCC, DAC, TCS,
  STC, DAA (both adjust and no-adjust paths, carry set and clear), KBP, DCL.

The testbench fails the run if any defined instruction is never executed.

## Scenario coverage

- Reset state and first fetch from PC 0; a mid-run reset between phases.
- ADD/SUB/ADM/SBM with and without carry/borrow, including the inverted
  carry-in subtract convention (spec 5.7).
- DAA with ACC 0-15 × CY 0/1 corner values; TCS with CY 0 and 1; KBP across
  all 16 input values via the random phase.
- 3-deep JMS/BBL subroutine nesting; a 4th JMS exercising the documented
  circular-overflow stack behavior and unwinding through BBL.
- ISZ loop-branch (taken) and skip paths, including a self-loop counting to
  zero.
- FIN indirect fetch with the pointer pair, including a FIN placed at word
  255 so the fetch page rolls into the next page (documented quirk); JIN;
  and a two-word ISZ straddling the 254/255 word boundary so its branch page
  is taken after the program-counter roll (documented quirk).
- SRC pointer selection of RAM chip/register/character and ROM chip;
  `cm_ram` bank decode across DCL values 0 (default), 1, 2, 3, and 7.
- Undefined opcode encodings (1111 1110, 1111 1111) behaving as NOPs.
- Fixed-seed pseudorandom phase: 8192 boundaries of random 1-word
  instructions (two-word opcodes replaced by INC at generation time), with
  full per-boundary state comparison.

## Formal coverage

The SBY `cover` task additionally proves reachability (non-vacuity) for
every instruction group, all 14 accumulator-group encodings, both JCN and
ISZ branch outcomes, stack-full (`sp == 3`), DCL bank registers, `cm_ram`
drive values, ROM-port drive, page-edge second-word fetch, and the TEST-pin
JCN condition. See `report/final_report.md` for the formal results.

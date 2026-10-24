# Formal Verification Plan: intel_8008

## Overview

Prove, for all opcode encodings and all reachable start states, the
instruction-boundary contract between the core and its memory/I/O environment:
retirement behavior per opcode class, stack discipline, bus strobe and address
correctness, and the documented no-effects of undefined encodings. Deep ISA
semantics are anchored by the SCELBAL regression (see
[the test plan](testplan.md)); the formal suite pins the control contract for
every encoding, including ones real software never executes.

## Scope

1. **Retirement contract per opcode class.** At every `retire` pulse, with the
   instruction's accept-time PC/SP/interrupt shadow (`f_pc`/`f_sp`/`f_int`):
   - class 0 (one byte: moves, register ALU, INR/DCR, rotates, INP/OUT, HLT,
     undefined NOPs): PC advances by one (or not, for an injected opcode), SP
     unchanged;
   - class 1 (two bytes: LdI, immediate ALU, LMI): PC advances by two total,
     SP unchanged;
   - class 2 (return family and RST): RET aliases pop unconditionally
     (`PC = stack[SP-1]`, `SP = SP-1`); RFc/RTc pop only when opcode bit 5
     matches the selected flag, else fall through; RST sets
     `PC = {000, vector, 000}`, `SP = SP+1`, and `stack[old SP] = return PC`
     (the un-advanced PC under interrupt);
   - class 3 (JMP/CAL and memory-cycle instructions): taken jumps land on the
     latched target, taken calls additionally push the third-byte successor
     address; not-taken branches advance by three; LdM/LMr/ALU-with-M retire
     with one byte advanced.
2. **Undefined INR/DCR M (octal 070/071)**: retirement advances the PC but
   leaves flags and the whole register file unchanged (review F1 fix).
3. **Bus protocol**: strobe mutual exclusion; per-state address/port selection
   (`mem_addr = PC` for fetch states, `{H[5:0], L}` for memory states,
   `io_port = op[5:1]` for I/O states); MEM_W data = immediate for LMI,
   source register otherwise; register write port stays in bounds.
4. **Ready freeze**: with `ready=0` the entire architectural state (PC, SP,
   opcode, state, flags, registers) holds.
5. **Reset**: first-cycle reset assumption keeps proofs non-vacuous; the RTL
   reset values are exercised by the simulation regressions.

## Non-Vacuity (cover)

Cover reaches: retirement, memory write, I/O write; HLT fetch; INR M and
DCR M fetch (the undefined encodings); RTc and RFc fetch (both return senses);
JMP/CAL fetch; instruction injection from HLT; and RST under interrupt.

## Method

All properties live in `` `ifdef FORMAL `` inside `intel_8008.sv` and run via
`scripts/run_formal.sh` (SymbiYosys, `abc pdr` for prove, `smtbmc z3` for
cover, depth 20/12). The shadow registers latch at the opcode-accept cycle so
every retire-pulse assertion compares the committed state against accept-time
expectations.

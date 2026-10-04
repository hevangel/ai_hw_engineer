# Am2910 verification report

Verified digital contract: all sixteen manufacturer instructions, twelve-bit
state, native rising-edge updates, five-entry saturating stack and real
condition/load/output-enable polarities. No reset pin or power-up clearing.

## Reproducible results

Toolchain ai-hw-engineer:latest: Verilator5.052, Yosys0.69, SymbiYosys/Z3/ABC.
Run `sh design/amd_am2910/scripts/run_all.sh`.

- Verilator `--lint-only -Wall`: clean, no suppressions.
- Manufacturer CSV generation check: passed. Oracle was transcribed before
  RTL from visually inspected Table I, not generated from RTL.
- 87,040 independent transition cases: 21,504 systematic combinations across
  all opcodes, five control pins, all six stack depths and seven counter
  boundary values, plus 65,536 deterministic random twelve-bit cases.
- 28,861 original Figure4 firmware words: exact executed linkage, next
  fetched address and post-edge PC; conditional/unconditional subroutine
  return, RFCT, RPCT, LOOP and all three TWB exits. Count range includes
  N=4095 (4096 passes). Unmapped execution is fatal; no padding landings.
- 1,444,321 checks passed, including counter probing and all active stack
  words through actual instructions. Empty-stack addresses are masked as
  undefined, and pin-driven direct jumps reestablish defined state.
- Formal BMC depth16, unbounded ABC PDR, and cover: PASS. Twenty-three cover
  properties include every opcode and boundary/priority cases. Covers start
  from legal arbitrary state; simulation starts with the real JZ opcode.
- Synthesis: 549 cells, 87 register bits (PC12, counter12, stack60, depth3),
  zero latches; Yosys check reports zero problems and synthesis no warnings.

ABC's formal conversion reports 72 undriven mux padding bits for addresses
outside the five-word array. These become arbitrary formal values; initial
legal depth plus the proven depth invariant and symbolic watched-address
constraint exclude those indices. No normal RTL synthesis warning is hidden.
ABC also reports its three constraint outputs, as expected for assumptions.

## Limits

Original Figure4 is a manufacturer control-flow program, with generic
sequential nodes explicitly instantiated as CONT; it is not a recovered full
machine application ROM. The independent table oracle is authoritative:
inspected third-party Am2900ME contains incompatible Am2910 instruction
semantics and is not used. Electrical setup/hold/delays and power-up values
are not modeled. Introduction-year evidence establishes presence by1978;
first production/shipment year remains uncertain.

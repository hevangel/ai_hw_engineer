# MOS Technology 6502

The 6502 was introduced in **1975** and became the CPU of the Apple II,
the Commodore PET, and the Nintendo Entertainment System. This directory
contains an original, synthesizable implementation of the **full documented
NMOS instruction set**: all 151 opcodes across the thirteen addressing
modes, the stack operations, BRK/RTI, level-triggered IRQ (I-masked) and
edge-triggered NMI, binary and decimal ADC/SBC, and the `JMP ($xxFF)`
page-wrap quirk. The core is instruction-accurate on a functional bus
(one transfer per clock); the separate native engine described below implements NMOS cycles against
the hardware manual.

Verification: a 770-instruction directed replay against the vendored py65
oracle (66,307 register checks plus a full memory-image compare, on
Verilator and xezim), SymbiYosys formal proofs (bounded progress, fetch
discipline, fault containment, interrupt-vector muxing, stack addressing,
B-flag push rules, with cover traces for every sequencer state), and — the
primary real-software gate — **Klaus Dormann's 6502 functional test,
passing to its success trap**. See
[report/final_report.md](report/final_report.md) and
[failure_notes/2026-10-13](../../../failure_notes/2026-10-13-mos6502-d1-cmp-zpy.md)
for the escaped-defect post-mortem (a D1 opcode misreading that the
directed suite could not catch because the oracle shared it).

Read the [stage-1 specification](spec/spec.md), the
[stage-2 full-ISA specification](spec/spec_full_isa.md) (with the
assumption ledger), the [implementation plan](plans/implementation_plan.md),
and the [validation report](report/final_report.md). `scripts/run_all.sh`
runs the complete flow: lint, formal (bmc/prove/cover), vector replay,
Klaus, the control unit test, coverage, and synthesis.

`references/` vendors the py65 MPU (BSD) as the ISS oracle and Klaus
Dormann's functional test (GPL, `6502_functional_test.a65` plus the
assembled `.bin.hex` used by the testbench) — both are verification
references only; neither is linked into the RTL.

The year is supported by the [IEEE historical exhibit](https://history.ieee.org/programs/ieee-global-museum/microchips-that-shook-the-world/). The exact commercial introduction date is not asserted. Instruction behavior is grounded in MOS Technology's [January 1976 programming manual](https://www.bitsavers.org/components/mosTechnology/6500-50A_MCS6500pgmManJan76.pdf); cycle timing must be checked against its [hardware manual](https://archive.6502.org/books/mcs6500_family_hardware_manual.pdf).

## Native NMOS engine

`src/mos_6502_native.sv` now provides a separate native bus-cycle engine,
including all 256 opcode slots, dummy accesses, RMW writes, control pins
and explicitly qualified unstable operations. It passes 2.56 million
external instruction cases, 770 die-derived netlist timing scenarios,
formal BMC/PDR/nine covers, historical Klaus and original KIM-1 software,
strict lint and synthesis. It does not yet establish every silicon or
console timing condition.

Read the [native specification and assumption ledger](spec/spec_native_bus.md),
[native plan](plans/native_implementation_plan.md) and
[measured native report](report/native_report.md). Run
`scripts/run_native_all.sh` for the native flow; `scripts/run_all.sh`
continues to verify the existing functional engine.

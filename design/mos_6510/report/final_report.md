# MOS 6510 sampled port and CPU verification

## Implemented behavior

The original RTL wraps the native NMOS core with eight-bit internal DDR/
data registers, six bonded pins, configurable sampled charge on unbonded
bits and explicit AEC bus-driver enables. Internal port writes update the
CPU latch while leaving the external data driver disabled. AEC does not
replace RDY. See the [specification and discrepancy ledger](../spec/spec.md)
for the independent sources and qualified defaults.

## Measured gates (2026-10-19)

Docker image `ai-hw-engineer:latest`: Verilator 5.052, xezim 0.11.0,
Yosys/SymbiYosys 0.69. The individual scripts below were run successfully;
`run_all.sh` aggregates them with the unchanged shared native CPU flow.

| Gate | Result |
|---|---|
| `run_lint.sh` | Strict Verilator `-Wall` RTL lint passes |
| `run_formal.sh` | Port BMC/PDR/3 covers and integrated CPU BMC/PDR/15 covers pass; port bound 16, CPU BMC 24/cover 40 |
| Port simulation | Verilator exhausts all 256 DDR × 256 latch × 64 physical-pin values: 4,194,304 combinations; xezim checks 16,384 combinations plus both upper-bit tests |
| Charge timing | Both simulators verify each unbonded bit stays charged for exactly the default 350,000 clocks after release, then reads zero; writing an input latch does not recharge it |
| CPU simulation | Both simulators pass 46 exact bus checks: DDR/data access, both old/new RMW writes under RDY low, driver enables, independent external RAM data, read stalls and AEC handoff; exact PCs/next opcodes |
| Historical software | Original KIM monitor on the actual 6510 wrapper passes both simulators: two ordered scans, 12 segment writes, one mask-RAM write after 8,533 clocks |
| Synthesis | Flattened generic Yosys synthesis and `check` pass, 4,463 cells |

Formal port proofs use falloff parameter 3 for reachable expiration covers.
Default-width/default-duration behavior is exercised by simulation, not
claimed proved from the small-parameter proof alone. The integrated proof
also includes the shared native CPU assertions and reachable NMI cover.

The unchanged shared CPU engine already passes its full native flow:
2,560,000 independent opcode cases / 11,959,871 bus transactions, 770
die-derived timing scenarios / 69,300 cycles, formal, authentic Klaus
success at PC 3469 after 96,241,371 clocks and original KIM firmware. Its
[native report](../../mos_6502/report/native_report.md) states remaining
NMOS timing limits. None of those inputs are generated from this RTL.

## Test fixture correction

The first xezim CPU-bench attempt exceeded its memory watchdog while
elaborating a dense 64 KiB test RAM. The fixture now decodes only its
32-byte instruction ROM, two external zero-page bytes, four result bytes
and reset vectors. It rejects unexpected writes and checks the same exact
instruction and bus sequence. This changes the simulation fixture, not
CPU behavior or expected values; both simulators now complete it.

## Remaining silicon and C64 gates

The VICE zero-reset profile differs from MAME's FF reset values. The
deterministic charge profile excludes temperature/die variation and the
reference emulator's randomized falloff. These assumptions need physical
validation before final silicon sign-off. The external port-write bus
behavior follows the pinned VICE C64 memory implementation and also needs
capture validation. Oscillator/subcycle AEC/RDY timing, C64 KERNAL/BASIC,
VIC-II/PLA/CIA arbitration, cassette behavior and raster/audio comparisons
remain system requirements. KIM is a real-software fixture, not a C64 build.

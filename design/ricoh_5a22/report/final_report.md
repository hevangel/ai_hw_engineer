# Ricoh 5A22 (S-CPU) verification

## Contract and evidence

`ricoh_5a22.sv` wraps the project's [WDC 65C816](../../wdc_65c816/) core
and adds the S-CPU logic: memory cycles of 6, 8 or 12 master clocks chosen
by address and MEMSEL, the 40-clock DRAM refresh per line, eight DMA
channels with HDMA (direct and indirect, all transfer patterns, line
counter repeat), the H/V counters with NMI, IRQ and the H/V timer, the
multiplier and divider with their hardware delays, manual and automatic
joypad reading, and the B-bus interface. Everything runs on the master
clock with clock enables. The [specification](../spec/spec.md) lists
sources and the assumption ledger.

There is no chip-level testbench: the chip is verified on the
[SNES board](../../../system/snes/) by real software with independent
expected results (Peter Lemon's test ROMs at revision
`350b394e86ec5d62f600b5cbf64cdce3721bb6ef` and their reference
screenshots). `scripts/run_test.sh` runs the CPU, bank and HDMA subset.

## Results (2026-10-27)

Cloud container: Verilator 5.020, Yosys 0.33. Formal and coverage flows
were not run; the Docker image run of `scripts/run_all.sh` is still owed.

| Gate | Measured result |
|---|---|
| Strict lint | `verilator --lint-only -Wall` passes |
| Real software | 23/23 `CPUTest/CPU` ROMs and 5/5 `BANK` ROMs (LoROM/HiROM, SlowROM/FastROM, WRAM) pass; the HDMA ROMs (HiColor 64 and 128 per tile row, Mode7HDMA, RedSpace9BitHDMA, WaveHDMA, WindowHDMA) match their screenshots, which depends on per-line HDMA timing |
| Synthesis | Generic Yosys synthesis and `check -assert` pass: 20,047 cells |

`CPUMSC` executes STP and asks for the reset button; the harness presses it
and the test then completes.

## Known differences

None attributed to this chip. The two pseudo-high-resolution HiColor ROMs
in the HDMA subset are reported as KNOWN (a column-0 difference in the
[5C78](../../ricoh_5c78/)); they exercise HDMA, which works.

## Remaining gates

The DMA A-bus to work-RAM B-bus case and the version-1 HDMA/DMA crash are
not modelled. Open bus on unmapped I/O follows the CPU data latch only. No
chip-level testbench, formal properties or coverage closure exist yet.

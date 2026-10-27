# Sony S-SMP verification

## Contract and evidence

`sony_s_smp.sv` wraps the project's [SPC700](../../sony_spc700/) core and
adds the S-SMP glue: the 64-byte IPL ROM (loaded at start-up, never stored
in the repository), the IPL enable and port-clear bits of CONTROL, the
four bidirectional CPU ports, timers 0 and 1 (8 kHz) and 2 (64 kHz) with
their 4-bit counters cleared on read, the TEST register fields, and the
`$F2/$F3` window into the [S-DSP](../../sony_s_dsp/). One SPC700 cycle runs
per 1.024 MHz clock enable from the board. The
[specification](../spec/spec.md) lists sources and assumptions A1–A4.

The chip is verified on the [SNES board](../../../system/snes/) by Peter
Lemon's SPC700 test ROMs (revision
`350b394e86ec5d62f600b5cbf64cdce3721bb6ef`), which upload test programs
through the IPL protocol and print each result on screen; the screen must
match the author's screenshot and must never show FAIL.
`scripts/run_smp_test.sh` runs that subset.

## Results (2026-10-27)

Cloud container: Verilator 5.020, Yosys 0.33. Formal and coverage flows
were not run; the Docker image run of `scripts/run_all.sh` is still owed.

| Gate | Measured result |
|---|---|
| Strict lint | `verilator --lint-only -Wall` passes |
| Real software | 7/7 `CPUTest/SPC700` ROMs (ADC, AND, DEC, EOR, INC, ORA, SBC) match their screenshots after 1,005–2,039 frames; they time every case with the S-SMP timers. The 9 sound demos upload their driver through the IPL and produce sound |
| Synthesis | Generic Yosys synthesis and `check -assert` pass: 14,391 cells |

## Known differences

None observed.

## Remaining gates

TEST wait states are stored but not applied (A1). No chip-level testbench,
formal properties or coverage closure exist yet.

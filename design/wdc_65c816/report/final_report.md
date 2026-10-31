# WDC W65C816S verification

## Contract and evidence

`wdc_65c816.sv` is an original cycle-level model of the W65C816S: one bus
cycle per clock enable, with the address, data, R/W and the VDA, VPA, VPB
and ML qualifiers of every cycle, including dummy reads, internal cycles
and the extra cycles for a non-zero direct-page low byte, page crossings,
16-bit accesses and the native/emulation-mode stack behaviour. Decimal
mode, NMI, IRQ, BRK, COP, WAI and STP are included. The
[specification](../spec/spec.md) lists sources and the assumption ledger.

The independent oracle is the SingleStepTests 65816 record set at revision
`307c63f5673c8c6b861c52f71ddb89212a227480`. `scripts/fetch_cpu_tests.py`
downloads it into ignored `work/`, records SHA-256 hashes in a manifest and
converts it to plain text; expected values come only from those files.

## Results (2026-10-27)

Cloud container: Verilator 5.020, Yosys 0.33. Formal and coverage flows
were not run for this chip; the project Docker image run of
`scripts/run_all.sh` is still owed.

| Gate | Measured result |
|---|---|
| Strict lint | `verilator --lint-only -Wall` passes |
| SingleStepTests | `WDC 65C816 CPU VECTOR PASS: cases=5080400 opcode_modes=512 bus_cycles=26144846`: every record of all 256 opcodes in native and emulation mode, each bus cycle and the final register and memory state compared |
| Synthesis | Generic Yosys synthesis and `check -assert` pass: 11,583 cells |
| Real software (SNES system) | All 23 Peter Lemon `CPUTest/CPU` ROMs and the 5 `BANK` ROMs pass inside the [Ricoh 5A22](../../ricoh_5a22/) on the SNES board |

`scripts/run_cpu_vectors.sh` defaults to 500 records per file
(`PER_FILE`), which runs in a few minutes; the full set above was run with
`PER_FILE=0`.

## Known differences

None observed against the oracle.

## Remaining gates

ABORTB, RDY as an input, BE and the multiplexed bank byte on D7–D0 are not
modelled because the 5A22 does not use them. No formal properties or
coverage closure exist yet.

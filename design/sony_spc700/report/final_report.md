# Sony SPC700 verification

## Contract and evidence

`sony_spc700.sv` is an original cycle-level model of the SPC700 core: one
bus cycle per clock enable, with reads (including the dummy reads),
writes and internal cycles in hardware order for all 256 opcodes,
including MUL, DIV, DAA/DAS, the bit instructions, TCALL, SLEEP and STOP.
The [specification](../spec/spec.md) lists sources and the assumption
ledger.

The independent oracle is the SingleStepTests spc700 record set at
revision `67d15f492b2740964abd4efd1229e0ec9c342228`, fetched and
hash-recorded by `scripts/fetch_cpu_tests.py` into ignored `work/`.

## Results (2026-10-27)

Cloud container: Verilator 5.020, Yosys 0.33. Formal and coverage flows
were not run; the Docker image run of `scripts/run_all.sh` is still owed.

| Gate | Measured result |
|---|---|
| Strict lint | `verilator --lint-only -Wall` passes |
| SingleStepTests | `SONY SPC700 CPU VECTOR PASS: cases=256000 opcodes=256 bus_cycles=1182940`: 1,000 records per opcode, each bus cycle and the final state compared |
| Synthesis | Generic Yosys synthesis and `check -assert` pass: 12,293 cells |
| Real software (SNES system) | Inside the [S-SMP](../../sony_s_smp/): the 7 Peter Lemon `CPUTest/SPC700` ROMs pass (1,000–2,000 frames each) and the 9 music and sample demos produce sound |

## Known differences

None observed against the oracle.

## Remaining gates

The core has no interrupt inputs, as in the S-SMP. No formal properties or
coverage closure exist yet.

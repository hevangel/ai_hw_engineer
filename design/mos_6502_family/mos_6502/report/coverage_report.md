# MOS 6502 full-ISA — Coverage Report

Tool: xezim 0.10.5 `--code-coverage --code-coverage-scope tb_top.dut`,
driven by the vector-regression testbench (`scripts/run_coverage.sh`, raw
JSON at `work/coverage/rtl.json`).

## Result

| Metric | Coverage |
| --- | --- |
| Statement | 411/417 (98.56%) |
| Branch | 266/274 (97.08%) |
| Toggle | 703/732 (96.04%) |

The decode-coverage guarantee (every documented opcode exercises its decode
path) is enforced structurally by the vector regression: the generator
sweeps every documented opcode through every documented mode, and the
replay compares architect state at every instruction boundary.

## Uncovered lines (all accounted for)

- `src/mos_6502.sv:480` — software `BRK` (`O_BRK` through the SPEC decode).
  The vector bench exercises the identical BRK/push/vector sequence via the
  forced-IRQ hijack; the software-opcode entry point is exercised by the
  Klaus functional test (passing), which is not part of the coverage run.
- `src/mos_6502.sv:663, 709` — `default: state <= S_FAULT` arms in the
  sequencer, unreachable by construction (the decode functions classify
  every byte; formal proves only undocumented opcodes reach FAULT).
- `src/mos_6502.sv:815, 816` — the terminal `S_FAULT` self-loop and the
  sequencer `default` arm; the vector bench never executes an undocumented
  opcode, and formal cover traces demonstrate the fault path separately.

The remaining branch/toggle gaps are the same defensive arms plus
carry/flag toggles only reachable from operand patterns outside the
directed sweep; the Klaus run and the formal cover statements exercise
them outside this metric's scope.

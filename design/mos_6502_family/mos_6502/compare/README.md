# Cross-core differential check

Review item C3: two independent 6502 implementations live in this family, and a
decoder or ALU defect could exist in one and not the other. This fixture runs
the same program on both and compares architectural state at every opcode
fetch.

| File | Role |
|---|---|
| `dual_6502_top.sv` | wrapper instantiating `mos_6502` (functional bus) and `mos_6502_cycle` (physical bus) with independent clocks and buses |
| `dual_test.cpp` | driver: two memories, one tick per bus transfer, comparison at each fetch |
| `run.sh` | builds with Verilator and runs both phases |
| `negative_control.sh` | rebuilds with one corrupted read in core B and requires the comparison to fail |

## What is compared

At every opcode fetch: PC, A, X, Y, SP, P (bit 4 masked) and memory
**contents**. A running hash covers every write, and the whole 64 KiB image is
compared byte-for-byte every 1,048,576 instructions and at the trap, so a hash
collision cannot hide a divergence. Cycles are deliberately not compared: the
cycle core models dummy reads and read-modify-write double writes that the
functional core omits, so the write *sequence* differs while the resulting
memory does not. An earlier version hashed write events and reported a false
divergence at instruction 47,072 that byte comparison showed to be a dummy write
of the old value.

The two cores also use different power-up conventions (SP 0x00 vs 0xFD, V 0 vs
1). Each phase runs a short software preamble — `LDX #$FF; TXS; CLV` — before
comparison starts, so the reset convention is not what gets tested.

## Result

```
PASS differential directed: 15 instructions, trap at 8012
PASS differential Klaus: 30646183 instructions, trap at 3469
PASS differential negative control: injected read fault detected
```

The control corrupts one read in core B; the run reports
`DIFF at instruction 5: A` and exits nonzero. A harness that silently matched
would look the same as a passing one, so the failure is part of the gate.

The second phase runs Klaus Dormann's functional test binary on both cores from
the same image and reset vector. Both reach the success trap at `$3469` with
identical registers and memory at every one of 30,646,183 instruction
boundaries. Build plus run takes about 90 s.

## Limits

- Proves agreement, not correctness: a shared misreading of the 6502 semantics
  would agree on both cores. The independent oracles (py65, SingleStepTests,
  perfect6502) remain the correctness evidence.
- Illegal/undocumented opcodes are outside the comparison; the cycle core
  faults where the functional core treats them as NOPs.
- The Klaus image is the standard `bin_files` build; the cycle core's own gate
  already pins the success PC.

Run it with `sh compare/run.sh` and `sh compare/negative_control.sh`;
`mos_6502/scripts/run_all.sh` calls both after the single-core gates.

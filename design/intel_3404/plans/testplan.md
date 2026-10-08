# Test Plan: Intel 3404

## Verification Goals

- Reset lands deterministically (reconstruction artifact; spec A3).
- A section whose write enable is low follows the inverted data at the
  sampling edge; a section whose enable is high holds its stored value
  even while its data inputs change.
- The 4-bit and 2-bit sections never interact: a write to one leaves the
  other frozen and simultaneous writes land independently.
- Long random sequences match a shadow model.

## Testbench Architecture

Plain self-checking SystemVerilog bench. A shadow model replicates the
specification in a separate `always @(posedge clk)` block; every check
compares DUT outputs against it after the settling point of each edge.
Directed tasks exercise each section's transparent write and
hold-against-disturbance corners; a 5000-cycle random phase sweeps all
data/write-enable combinations.

Formal carries the semantic load independently: the write/hold
properties are formulated from the datasheet timing diagram (setup/hold
around the rising edge), not from the RTL enable structure, and the
section-independence properties are asserted separately.

## Test Categories

### Directed Tests

| Test | Description | Priority |
|------|-------------|----------|
| `reset` | Outputs high after the reset edge | P1 |
| `write4` / `hold4` | 4-bit transparent write; held value immune to data disturbance | P1 |
| `write2` / `hold2` | 2-bit transparent write; held value immune to data disturbance | P1 |
| `simultaneous` | Both sections written with independent values | P1 |

### Random Tests

| Test | Description | Constraints |
|------|-------------|-------------|
| `random` | 5000 cycles, all data/enable combinations | LCG-seeded, deterministic |

## Coverage Plan

- Formal covers: write-with-other-held in both directions, simultaneous
  write, both-held, an all-zero/all-one write pattern, reset cycle.
- Code coverage (xezim): statement, branch and toggle closure on the DUT;
  random phase drives both enable states, all data bits and all stored
  bit positions through both polarities.

## Pass/Fail Criteria

- `intel_3404 TEST PASSED` in both Verilator and xezim logs
- Formal bmc/prove/cover all PASS
- Coverage: 100% statement/branch, full input/output toggle

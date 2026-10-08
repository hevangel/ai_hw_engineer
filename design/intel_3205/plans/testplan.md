# Test Plan: Intel 3205

## Verification Goals

- Every documented input combination (2^6 = 64) produces the datasheet
  truth-table output.
- The datasheet's decoder-expansion cascade (one decoder enabling eight
  others) behaves as a flat 6-bit one-of-64 decode.
- Formal proofs are non-vacuous: each of the eight selected outputs and
  the all-disabled state are covered.

## Testbench Architecture

Plain self-checking SystemVerilog bench (repo precedent for COTS
small-scale parts; no UVM). The bench instantiates the DUT, drives all
input combinations with `#1` settling delays, and compares against
expected vectors computed independently of the RTL equations.

A second hierarchy instantiates nine 3205s (one root, eight leaves whose
active-low enable comes from a root output) and checks the 64-output
network against a flat decode.

## Test Categories

### Directed Tests

| Test | Description | Priority |
|------|-------------|----------|
| `exhaustive` | All 64 enable/address combinations | P1 |
| `cascade` | 64 combinations through the two-level network | P1 |

## Coverage Plan

- Formal covers: each of the eight decoded outputs low; disabled/all-high.
- Code coverage (xezim): statement, branch and toggle closure on the DUT;
  the exhaustive sweep drives every input bit through both polarities.

## Pass/Fail Criteria

- `intel_3205 TEST PASSED` in both Verilator and xezim logs
- Formal bmc/prove/cover all PASS
- Coverage: 100% statement/branch, full input/output toggle

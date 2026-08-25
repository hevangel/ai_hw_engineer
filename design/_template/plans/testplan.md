# Test Plan: [CHIP_NAME]

## Overview

This document defines the verification strategy for [CHIP_NAME].

## Verification Goals

- Functional correctness of all specified features
- Protocol compliance on all interfaces
- Corner-case coverage via constrained random
- Error injection and recovery
- Performance validation

## Testbench Architecture

```
UVM Test
  └── UVM Environment
        ├── Agent (Interface 1)
        │   ├── Driver
        │   ├── Monitor
        │   └── Sequencer
        ├── Agent (Interface 2)
        │   ├── Driver
        │   ├── Monitor
        │   └── Sequencer
        ├── Scoreboard
        └── Coverage Collector
```

## Test Categories

### Directed Tests

| Test Name | Description | Priority |
|-----------|-------------|----------|
| `base_test` | Basic connectivity, reset behavior | P1 |
| `smoke_test` | Simple end-to-end transaction | P1 |

### Constrained Random Tests

| Test Name | Description | Constraints |
|-----------|-------------|------------|
| `random_test` | Random stimulus with all knobs | Default constraints |
| `stress_test` | Back-to-back transactions | Min delay, max throughput |
| `corner_test` | Edge cases | Boundary values |

### Error Tests

| Test Name | Description | Expected Behavior |
|-----------|-------------|-------------------|
| `error_inject_test` | Protocol violations | Proper error signaling |

## Coverage Plan

### Functional Coverage

| Covergroup | Description | Target |
|------------|-------------|--------|
| `cg_opcodes` | All operation types | 100% |
| `cg_sizes` | All transfer sizes | 100% |
| `cg_sequences` | Important sequences | 95% |

### Code Coverage Targets

| Metric | Target |
|--------|--------|
| Line coverage | > 95% |
| Toggle coverage | > 80% |
| FSM coverage | 100% |
| Branch coverage | > 90% |

## Regression Strategy

1. **Smoke regression**: 5-10 tests, run on every commit
2. **Nightly regression**: Full test suite, 100+ seeds
3. **Coverage closure**: Targeted tests for holes

## Pass/Fail Criteria

- `UVM_ERROR : 0`
- `UVM_FATAL : 0`
- Scoreboard comparison match
- No assertion violations
- Coverage targets met

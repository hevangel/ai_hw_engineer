# Implementation Plan: [CHIP_NAME]

## Overview

Brief description of the chip and its purpose.

## Architecture

High-level block diagram and architecture description.

## Module Hierarchy

```
chip_top
├── module_a
│   ├── sub_a1
│   └── sub_a2
├── module_b
└── module_c
```

## Implementation Phases

### Phase 1: Core Logic
- [ ] Define interfaces and port list
- [ ] Implement core datapath
- [ ] Add control logic
- [ ] Initial lint check

### Phase 2: Integration
- [ ] Connect sub-modules
- [ ] Add clock/reset distribution
- [ ] Add configuration registers (if any)

### Phase 3: Verification-Ready
- [ ] Add SVA assertions inline
- [ ] Add coverage points
- [ ] Create synthesis constraints

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Clock scheme | Single clock | Simplicity |
| Reset | Synchronous active-low | Standard practice |
| Interface | AXI-Lite | Widely supported |

## Constraints

- Target frequency: TBD
- Area budget: TBD
- Power budget: TBD

## Dependencies

- None / List dependencies on other modules

## Schedule

| Milestone | Target Date | Status |
|-----------|-------------|--------|
| RTL complete | | Not started |
| Formal clean | | Not started |
| UVM TB complete | | Not started |
| Coverage closure | | Not started |
| Sign-off | | Not started |

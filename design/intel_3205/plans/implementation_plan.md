# Implementation Plan: Intel 3205

## Overview

Functional reconstruction of the Intel 3205 high-speed 1-of-8 binary
decoder, the MCS-8 chip-select/state-decode support part documented in the
November 1973 MCS-8 Users Manual and the combined Intel 3205/3404 data
sheet.

## Architecture

Purely combinational, single module, no clock or reset. An enable gate
(E1̅ AND E2̅ AND E3) qualifies a one-hot active-low decode of the three
address inputs; a disabled decoder drives all outputs high.

## Implementation Phases

### Phase 1: Core Logic
- [x] Port list mirroring the datasheet pin functions (logical, not pins)
- [x] Enable gate and active-low one-hot decode
- [x] Verilator lint clean with `-Wall`, no waivers on RTL

### Phase 2: Verification-Ready
- [x] Formal properties module (`intel_3205_props.sv`): per-output
      truth-table assertions formulated as an independent decode loop,
      one-hot/non-vacuity assertions, per-output and disabled covers
- [x] Self-checking testbench: exhaustive 64-combination truth-table sweep
      plus the datasheet's two-level cascade arrangement (root drives eight
      leaves through their enables, checked against a flat 6-bit decode)

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Combinational, no reset | No clock/reset ports | Datasheet: no storage elements on the part |
| Active-low ports carry `_n` suffixes | Repo port naming convention | Polarity visible at call sites |
| Shift-based decode | `~(8'b1 << a_i)` | Matches one-hot semantics directly; formal checks an independent loop formulation |

## Constraints

- Target: generic synthesis only; the device is small-scale TTL-era logic.

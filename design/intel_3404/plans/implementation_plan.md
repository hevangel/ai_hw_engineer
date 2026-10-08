# Implementation Plan: Intel 3404

## Overview

Functional reconstruction of the Intel 3404 high-speed 6-bit latch — the
MCS-8 address/flag latch documented in the November 1973 MCS-8 Users
Manual and the combined Intel 3205/3404 data sheet. Six inverting latch
stages organized as an independent 4-bit section (write enable pin 7)
and 2-bit section (write enable pin 15), transparent while the write
enable is low and storing on its rising edge.

## Architecture

Single sequential module: two independently enabled register groups in
the inverted data domain, a 4-bit group and a 2-bit group. `clk` and
`rst_n` are reconstruction artifacts documented in the spec's assumption
ledger (the physical part is an asynchronous latch with no reset).

## Implementation Phases

### Phase 1: Core Logic
- [x] Port list: six data inputs, two active-low write enables, six
      inverted outputs
- [x] Independent write/hold per section, reset artifact
- [x] ASSUMPTION comments (A1-A3) inline in the RTL
- [x] Verilator lint clean with `-Wall`, no waivers on RTL

### Phase 2: Verification-Ready
- [x] Formal properties: write-follows-data and hold-stability per
      section derived from the datasheet timing diagram, section
      independence asserted separately, reset landing, six covers for
      non-vacuity
- [x] Self-checking testbench: directed reset/write/hold/independence/
      simultaneous-write checks plus 5000 cycles of random stimulus
      against a shadow model

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Inverted storage domain (`q4_n`, `q2_n`) | Store the complemented data | Outputs are the physical device's only view; the inverted-domain registers make `q_n_o` a pure assign |
| Active-low write enables in RTL | Match physical polarity (`w4_n_i`, `w2_n_i`) | Keeps the transparency rule ("inverters when Write is low") visible in the code |
| Synchronous sampling of transparency | `always_ff @(posedge clk)` | Repo convention for sequential functional reconstructions; deviation documented in spec A3 |

## Constraints

- Target: generic synthesis only.

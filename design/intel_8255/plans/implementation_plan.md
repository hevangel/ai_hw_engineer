# Implementation Plan: Intel 8255

## Objective

Implement a single-module, synthesizable reconstruction of the Intel 8255A digital programming model, including Modes 0, 1, and 2, BSR, Port C handshake multiplexing, and interrupt-enable behavior.

## Architecture

```text
                           +---------------------------+
CPU controls/data -------->| bus decode + control word |
                           +-------------+-------------+
                                         |
                  +----------------------+----------------------+
                  |                      |                      |
          +-------v-------+      +-------v-------+      +-------v-------+
          | Port A latches|      | Port B latches|      | Port C latch |
          | IBF/OBF state |      | IBF/OBF state |      | and mux/INTE |
          +-------+-------+      +-------+-------+      +-------+-------+
                  |                      |                      |
             PA i/o/oe              PB i/o/oe              PC i/o/oe
```

The core uses one `always_ff` process for all state and one `always_comb` process for CPU read data, peripheral drive values, output enables, and interrupt equations. It detects sampled Port C handshake edges with a previous-input register.

## Module hierarchy

```text
intel_8255
├── CPU transaction decode
├── mode/control register
├── Port A input and output latches
├── Port B input and output latches
├── Port C output latch
├── Group A IBF/OBF/INTE state
├── Group B IBF/OBF/INTE state
├── handshake edge detection
└── combinational port/status/read muxes
```

A single module is intentional: the state interactions are compact, and splitting the handshake/status muxes would obscure priority and mode dependencies.

## Implementation phases

### Phase 1: specification and interfaces

- [x] Define the CPU bus and split bidirectional peripheral interfaces.
- [x] Record the control-word formats and register map.
- [x] Define synchronous event ordering and deviations from the asynchronous original.

### Phase 2: core RTL

- [x] Implement reset and mode-set behavior.
- [x] Implement Mode 0 data and direction handling.
- [x] Implement BSR and hidden INTE controls.
- [x] Implement Mode 1 input/output handshakes for both groups.
- [x] Implement Mode 2 independent Port A input/output handshakes.
- [x] Implement Port C status/data and output-enable multiplexing.
- [x] Add explicitly connected property modules under `FORMAL`.

### Phase 3: verification

- [x] Add a self-checking procedural testbench with a separately organized software-style model.
- [x] Add specification-derived black-box Mode 2 bus-ownership checks.
- [x] Exercise reset, all direction combinations, BSR, both Mode 1 directions, Mode 2, invalid bus controls, and reconfiguration.
- [x] Add formal safety, equivalence, reset-priority, and causal non-vacuity properties.
- [x] Run strict lint, simulation, BMC, proof, cover, and synthesis.

### Phase 4: evidence and review

- [x] Capture exact test counts and proof results.
- [x] Record synthesis utilization and scope limits.
- [x] Update the chip index and historical README.
- [x] Remediate the initial semantic review's Mode 2 bus-ownership finding.
- [x] Complete semantic re-review with a READY verdict.

## Design decisions

| Decision | Choice | Rationale |
|---|---|---|
| Core timing | Single rising-edge clock | Portable synthesis for a historically asynchronous device |
| Reset | Synchronous active high | Matches the original RESET polarity; specification explicitly overrides repository default |
| Bidirectional pins | Separate `i`, `o`, and per-bit `oe` | Avoids internal tri-states and supports FPGA/ASIC wrappers |
| CPU strobes | Active-low levels sampled on `clk` | Preserves historical signal names while making acceptance deterministic |
| Architecture | One module | Keeps mode priority, handshake flags, and Port C overrides visible together |
| Interrupts | Combinational qualified status equations | Reproduces INTE, buffer state, and returned handshake-level qualification |
| Mode 2 drive | Drive PA while sampled `ACK_A_n` is low | Matches the documented peripheral-controlled tri-state output-enable phase; `OBF_A_n` only advertises pending data |
| Verification oracles | Separately organized state model, specification-derived directed checks, and formal properties | Exposes protocol mistakes that a structurally similar model can share with the RTL |

## Constraints and dependencies

- IEEE 1800-2017 SystemVerilog.
- No vendor primitives or generated IP.
- Tools supplied by image `sha256:d2ffb0d844d69e4de521c2c8e376d46ea34f6edfec1d5069039895c1b2e6f147`.
- No target clock or area budget; generic Yosys synthesis is the structural acceptance test.
- External asynchronous handshakes require integration-level synchronization.

## Milestones

| Milestone | Status |
|---|---|
| Specification complete | Complete |
| RTL complete | Complete |
| Formal clean | Complete |
| Simulation complete | Complete |
| Synthesis complete | Complete |
| Documentation and automated gates | Complete |
| Semantic re-review | READY; no findings |

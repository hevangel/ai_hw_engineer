# Formal Verification Plan: Intel 8255

## Scope

Formal verification targets reset, mode decoding, output-enable safety, Port C handshake multiplexing, BSR behavior, and one-step/sequential handshake state transitions. The DUT instantiates an explicitly connected property module under `FORMAL`; no unsupported hierarchical references are used.

Analog behavior, metastability, and unbounded environment liveness are outside formal scope.

## Safety and equivalence properties

| ID | Property | Priority |
|---|---|---|
| S1 | Reset establishes all-input Mode 0 externally observable behavior | P1 |
| S2 | Invalid simultaneous CPU read/write never drives CPU read data | P1 |
| S3 | Control-address reads never drive CPU read data | P1 |
| S4 | DUT CPU read value/enable equals the specification-derived reference mux | P1 |
| S5 | PA/PB/PC output values and enables equal the specification-derived reference mux | P1 |
| S6 | Mode-set clears output and handshake state in the following cycle | P1 |
| S7 | BSR changes only the selected Port C latch bit and applicable INTE control | P1 |
| S8 | Input strobe captures peripheral data and sets IBF | P1 |
| S9 | CPU input read clears the applicable IBF | P1 |
| S10 | CPU output write asserts the applicable active-low OBF | P1 |
| S11 | Acknowledge returns the applicable active-low OBF high | P1 |
| S12 | Mode 2 PA output enable follows low `ACK_A_n`, independently of pending-data `OBF_A_n` | P1 |
| S13 | Handshake input pins are never driven and status pins are always driven | P1 |
| S14 | Interrupt outputs equal their documented INTE/status/handshake equations | P1 |

The synthesized proof cone contains 61 assertion outputs after packed/vector properties are lowered.

## Reachability covers

| ID | Scenario |
|---|---|
| C1 | Mode 0 drives all peripheral ports |
| C2 | Group A Mode 1 input reaches IBF and INTR |
| C3 | A Group A output write is followed by ACK and qualified INTR |
| C4 | Group B Mode 1 input reaches IBF and INTR |
| C5 | A Group B output write is followed by ACK and qualified INTR |
| C6 | Mode 2 drives Port A while `ACK_A_n` is low |
| C7 | Mode 2 has input and output pending while ACK is high and Port A is released |
| C8 | A PC7 BSR command causes the visible Port C latch effect |
| C9 | Reconfiguration after a non-default mode returns to `8'h9b` |
| C10 | A CPU read coincides with an input-capture edge |
| C11 | A CPU output write coincides with an acknowledge edge |
| C12 | A later reset concurrent with a write takes priority and restores reset state |

A reachability-only module is selected for the cover task. It observes the same DUT state but omits proof-only transition assertions, allowing all covers to solve quickly.

## Assumptions

| ID | Assumption | Rationale |
|---|---|---|
| A1 | Reset is asserted in the initial formal cycle | Establishes one known architectural start state |

Reset is unconstrained after the initial cycle, so arbitrary later reset assertions and reset priority are included in BMC and proof. CPU controls, address/data, peripheral data, and handshake transitions also remain unconstrained. No bus-legality, fairness, or environmental timing assumption is made.

## Proof strategy

| Task | Engine | Mode | Bound/result target |
|---|---|---|---|
| `bmc` | ABC `bmc3` | bounded safety | 12 frames |
| `prove` | ABC `pdr` | unbounded safety | convergence |
| `cover` | `smtbmc --syn --nopresat z3` | reachability | depth 20 |

Task-qualified read commands select the full property module for BMC/proof and the smaller cover module for reachability.

## File organization

```text
formal/
├── intel_8255_props.sv   — full safety/equivalence properties
├── intel_8255_cover.sv   — lightweight causal non-vacuity covers
└── intel_8255.sby        — bmc/prove/cover tasks
```

## Final status

- BMC: PASS through 12 frames.
- PDR: PASS, 61/61 assertion outputs proved; converged at frame 2.
- Cover: PASS, 12/12 statements reached; maximum witness depth 5.
- No counterexample, timeout, unknown result, or over-constraining indication remains.

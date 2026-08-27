# Formal Verification Plan: Intel 8259A

## Scope

Formal verification targets reset behavior, initialization state, the interrupt
vector/opcode/address output, the CPU read data, the interrupt-request logic,
cascade and buffer-enable outputs, mask updates, and end-of-interrupt clearing.
The DUT instantiates explicitly connected property and cover modules under
`FORMAL`; no unsupported hierarchical references are used.

Analog behavior, metastability, and unbounded environment liveness are outside
formal scope.

## Safety and equivalence properties

The property module re-derives every output as a pure function of the registered
state and asserts equality with the DUT (combinational equivalence), adds
structural safety assertions, and proves the key sequential transitions.

| ID | Property | Priority |
|---|---|---|
| S1 | `int_o` equals the nested / SFNM / special-mask request equation | P1 |
| S2 | `data_o`/`data_oe` equal the acknowledge and read output derivation | P1 |
| S3 | `cas_o`/`cas_oe` equal the cascade-drive derivation | P1 |
| S4 | `en_n_o`/`en_n_oe` equal the buffered-mode derivation | P1 |
| S5 | `data_oe` is asserted only during a valid read or an acknowledge drive | P1 |
| S6 | `int_o` implies the device is initialized and an unmasked request exists | P1 |
| S7 | `cas_oe` is all-zero or all-one, and non-zero only for a master driving a slave line | P1 |
| S8 | Synchronous reset establishes the un-initialized state | P1 |
| S9 | ICW1 restarts initialization and clears operating state | P1 |
| S10 | The mask register changes only through OCW1 (outside reset/ICW1) | P1 |
| S11 | Specific EOI clears exactly the addressed in-service bit | P1 |
| S12 | The initialization state and acknowledge phase stay within their legal ranges | P2 |

The synthesized proof cone contains 31 assertion outputs after packed and vector
properties are lowered.

## Reachability covers

Non-vacuity is demonstrated with a scripted-stimulus cover harness (see the
proof-strategy note below).

| ID | Scenario |
|---|---|
| C1 | The device reaches the initialized state |
| C2 | An interrupt is requested to the CPU |
| C3 | The MCS-86/88 vector byte is driven on the second acknowledge pulse |
| C4 | A master drives the cascade address for a slave line |
| C5 | A CPU register read drives the bus |
| C6 | Priority is rotated away from the reset order |
| C7 | Rotate-in-automatic-EOI mode is active |
| C8 | Special mask mode enables an interrupt while a level is in service |

## Assumptions

| ID | Assumption | Rationale |
|---|---|---|
| A1 | Reset is asserted in the initial formal cycle | Establishes one known architectural start state |

For BMC and proof, reset is unconstrained after the initial cycle, so arbitrary
later reset assertion and reset priority are included; CPU controls, address,
data, request lines, acknowledge, cascade input, and role pin are all
unconstrained. The cover harness additionally constrains the environment to a
single scripted stimulus trace (see below); that constraint applies only to the
cover task.

## Proof strategy

| Task | Engine | Mode | Bound/result target |
|---|---|---|---|
| `bmc` | ABC `bmc3` | bounded safety | 20 frames |
| `prove` | ABC `pdr` | unbounded safety | convergence |
| `cover` | `smtbmc --syn --nopresat --unroll z3` | reachability | depth 30 |

Note on the cover engine: the AIG-based ABC engine used for BMC and proof
converges in under a second on this design, but SBY does not support cover mode
with the ABC engine. The only available SMT solver, Z3, does not scale on this
circuit's default incremental encoding (bounded model checking does not converge
even at shallow depth). Enabling the `--unroll` option makes Z3 converge quickly,
and the cover harness pins every bus input to a deterministic scripted trace with
a cycle counter so each cover has a single, concrete witness. This yields a fast,
deterministic non-vacuity result. Broad, unconstrained reachability across random
stimulus is provided by the simulation regression rather than by formal cover.

## File organization

```text
formal/
├── intel_8259_props.sv   — combinational equivalence and behavioral safety
├── intel_8259_cover.sv   — scripted-stimulus non-vacuity covers
└── intel_8259.sby        — bmc / prove / cover tasks
```

## Final status

- BMC: PASS through 20 frames; no assertion output reached.
- PDR: PASS, 31/31 assertion outputs proved; converged by frame 5.
- Cover: PASS, 8/8 cover statements reached; maximum witness step 26.
- No counterexample, timeout, unknown result, or over-constraining indication
  remains for the safety proofs.

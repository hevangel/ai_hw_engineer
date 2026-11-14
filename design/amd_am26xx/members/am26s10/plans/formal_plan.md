# Am26S10 formal plan

Reference: AMD 1974 Data Book pages 4-39..4-44; spec port-structure
note.

## Properties

1. Driver contract: enabled rows assert B̄ === !I; released rows assert
   B̄ === 'Z (all modes, `===` exactness).
2. Receiver contract: Z̄ === !B̄ for arbitrary bus levels (all modes).

## Scope

Purely combinational: depth-2 bmc is exhaustive over the input space
and prove is unbounded without induction difficulty.

## Environment boundary

The bus-net tie (one physical pin, two roles), pull-up bias and
party-line resolution between two instances are modeled and directed
in the testbench: Verilator/xezim resolve tristate nets with pullup
primitives correctly, while Yosys formal has no pull-up primitive and
rejects inout port directionality in the SMT2 backend. The split-port
RTL structure (driver output + receiver input for each bus pin) keeps
each role provable in formal; the tie is exercised in simulation.

## Covers (non-vacuity)

Enabled asserted/released rows per channel, released-bus rows per
channel, all-four-released, and all-four-driving-low states.

# Am26S11 formal plan

Reference: AMD 1974 Data Book pages 4-39..4-44; spec.

## Properties

1. Driver contract: enabled rows assert B̄ === I (non-inverting);
   released rows assert B̄ === 'Z (all modes, `===` exactness).
2. Receiver contract: Z̄ === !B̄ for arbitrary bus levels (all modes).

## Scope and environment boundary

As in the am26s10 formal plan: combinational, depth-2 bmc exhaustive,
prove unbounded; the bus-net tie, bias and party-line resolution are
simulation-directed (Yosys formal has no pull-up primitive and rejects
inout directionality).

## Covers (non-vacuity)

Enabled asserted/released rows per channel (non-inverting values),
released-bus rows, all-four-released, and all-four-driving-low states.

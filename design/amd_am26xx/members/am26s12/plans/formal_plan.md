# Am26S12 formal plan

Reference: 1974 Data Book pages 4-39..4-44; 1979 sheet pages 4-62..4-66;
spec.

## Properties

1. Driver contract: both-enables-low rows assert B̄ === !I; either-
   enable-high rows assert B̄ === 'Z (all modes, `===` exactness).
2. Receiver contract: Z̄ === !B̄ for arbitrary bus levels (all modes).

## Scope and environment boundary

Combinational, depth-2 bmc exhaustive, prove unbounded. The bus-net
tie, bias and party-line resolution are simulation-directed (Yosys
formal has no pull-up primitive and rejects inout directionality);
same boundary as the am26s10 formal plan. The Am26S12A member verifies
this same contract at REVISION 1 separately.

## Covers (non-vacuity)

Driven rows per channel (both polarities), either-enable release rows,
single-enable-release per enable pin, all-four-released, and
all-four-driving-low states.

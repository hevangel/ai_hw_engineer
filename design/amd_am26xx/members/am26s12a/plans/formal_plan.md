# Am26S12A formal plan

Reference: 1979 Linear and Interface Data Book pages 4-62..4-66; spec.

## Properties

Identical to the am26s12 formal plan — one truth table serves both
grades — evaluated on the REVISION 1 instance so the S12A contract is
verified separately per the parent issue's revision rule. The shared
source's elaboration-time margin check pins the S12A threshold pair.

## Scope and environment boundary

Combinational, depth-2 bmc exhaustive, prove unbounded; bus-net tie,
bias and party-line resolution are simulation-directed (same boundary
as the am26s10 formal plan).

## Covers (non-vacuity)

Driven rows per channel (both polarities), either-enable release rows,
single-enable-release per enable pin, all-four-released, and
all-four-driving-low states.

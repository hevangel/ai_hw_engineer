# Formal Verification Plan: Intel 3404

## Scope

The latch is fully specified by the datasheet: six inverting stages in
two independently enabled sections, transparent while the write enable
is low, storing on the rising edge. Formal proves write-follows-data,
hold-stability, section independence and reset landing for the complete
unconstrained input space, with covers establishing non-vacuity.

## Property Categories

### Safety Properties (assert)

| ID | Property | Priority |
|----|----------|----------|
| S1 | 4-bit section: enable low at the last edge implies stored bits equal the inverted data at that edge | P1 |
| S2 | 4-bit section: enable high at the last edge implies stored bits unchanged | P1 |
| S3 | 2-bit section: same write/hold pair as S1/S2 on bits `[5:4]` | P1 |
| S4 | Independence, stated separately: a cycle with either enable high leaves that section's stored bits unchanged regardless of the other section's activity | P1 |
| S5 | Reset landing: the cycle after a reset edge drives the inverted outputs high | P1 |

### Liveness Properties (cover)

| ID | Property | Priority |
|----|----------|----------|
| L1 | 4-bit write while 2-bit holds | P1 |
| L2 | 2-bit write while 4-bit holds | P1 |
| L3 | Simultaneous write | P1 |
| L4 | Both sections hold | P1 |
| L5 | All-zeros/all-ones write pattern | P1 |
| L6 | Reset cycle reachable | P1 |

### Assumptions (assume)

| ID | Assumption | Rationale |
|----|------------|-----------|
| A1 | `rst_n` low in the initial cycle | Repo convention; deterministic start state (the physical part powers up indeterminate — spec A3) |

Inputs stay unconstrained beyond the initial reset assumption: every
data/enable combination is legal per the datasheet.

## Proof Strategy

| Task | Engine | Depth | Rationale |
|------|--------|-------|-----------|
| bmc | smtbmc z3 | 6 | Sequential design; covers need a few cycles of history |
| prove | smtbmc z3 | 6 | Unbounded induction over the 6 stored bits |
| cover | smtbmc z3 | 6 | Non-vacuity of L1-L6 |

One `.sby` file with `[tasks]` bmc/prove/cover.

## Success Criteria

- bmc/prove/cover all PASS
- All six covers reachable (non-vacuous)
- The single assumption is the initial-reset convention

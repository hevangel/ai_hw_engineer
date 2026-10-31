# Formal Verification Plan: Intel 3205

## Scope

The whole device is combinational and fully specified by the datasheet
truth table, so formal proves the complete contract: all 64 input
combinations against an independent per-output formulation, plus the
structural one-hot/no-stealth-select properties.

## Property Categories

### Safety Properties (assert)

| ID | Property | Priority |
|----|----------|----------|
| S1 | Every output `i` is low iff enabled and `a_i == i` (loop formulation, independent of the RTL shift) | P1 |
| S2 | Enabled implies exactly one output low (`$onehot(~out_n)`) | P1 |
| S3 | Disabled implies all outputs high | P1 |

### Liveness Properties (cover)

| ID | Property | Priority |
|----|----------|----------|
| L1 | Each of the eight outputs reachable in the selected (low) state | P1 |
| L2 | Disabled all-high state reachable | P1 |

### Assumptions (assume)

None. All 2^6 input combinations are legal per the datasheet; inputs stay
free so the assertions are universal.

## Proof Strategy

| Task | Engine | Depth | Rationale |
|------|--------|-------|-----------|
| bmc | smtbmc z3 | 2 | Combinational design; full input space is reached immediately |
| prove | smtbmc z3 | 2 | Unbounded proof of the same set |
| cover | smtbmc z3 | 2 | Non-vacuity of L1/L2 |

One `.sby` file with `[tasks]` bmc/prove/cover, mirroring the Am2902
precedent.

## Success Criteria

- bmc/prove/cover all PASS
- Covers non-vacuous (eight decoded covers + disabled cover reachable)
- No assumption over-constrains the input space

# Formal Verification Plan: alu_74181

## Scope

Prove the combinational RTL equivalent to the normalized TI table-1 reference, as separately coded in the formal harness, for arbitrary `a`, `b`, `s`, `m`, and `cn`. All 14 functional input bits are unconstrained, so a successful proof covers all 16,384 unique input assignments in one symbolic model.

## Reference Strategy

The formal harness re-implements the same normalized datasheet golden table used by simulation, without importing DUT equations or DUT internal signals. It is structurally independent from the RTL but intentionally not a separate specification source; review of the normalized table remains part of sign-off.

1. `expected_f` comes from a 16-entry logic table or a separate 16-entry 5-bit arithmetic-expression table.
2. `expected_cn4` comes from arithmetic expression bit 4; logic mode requires inactive HIGH.
3. `expected_p_bar` uses a four-entry `S1:S0` X-term table.
4. `expected_g_bar` uses a four-entry `S3:S2` Y-term table and the documented group lookahead expansion.
5. `expected_a_eq_b` is `&expected_f`.

A single packed assertion compares every output, preventing one output from passing while another is unchecked.

## Properties

| ID | Type | Requirement |
|---|---|---|
| F1 | assert | `f` matches all 16 logic functions for either `cn` |
| F2 | assert | `f` matches all 16 arithmetic functions for both `cn` states |
| F3 | assert | `cn4` matches the independent 5-bit result and is HIGH in logic mode |
| F4 | assert | `p_bar` matches group propagation for every A/B/S value |
| F5 | assert | `g_bar` matches group generation for every A/B/S value |
| F6 | assert | `a_eq_b` is HIGH exactly when all expected F bits are HIGH |
| C1 | cover | Logic and arithmetic modes are each reachable |
| C2 | cover | Active and inactive `cn4`, `p_bar`, and `g_bar` states are reachable |
| C3 | cover | `a_eq_b` active and inactive states are reachable |

## SymbiYosys Tasks

| Task | Mode | Engine | Depth | Purpose |
|---|---|---|---:|---|
| `bmc` | bmc | `abc bmc3` | 1 | Immediate combinational assertion check |
| `prove` | prove | `abc pdr` | 1 | Complete symbolic proof |
| `cover` | cover | `smtbmc z3` | 1 | Non-vacuity and output-state reachability |

## Success Criteria

- `bmc`, `prove`, and `cover` all return PASS.
- No assumptions constrain legal inputs.
- Every output is included in the packed equivalence assertion.
- Cover witnesses demonstrate both modes and active/inactive status outputs.
- Logs and exact tool versions are recorded in `report/final_report.md`.

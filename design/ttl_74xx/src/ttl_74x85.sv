// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x85 - 4-bit magnitude comparator
//
// Compares A and B (4 bits each) and produces a-less-than-b, a-equal-b, and
// a-greater-than-b outputs. Three cascade-input pins let multiple 7485s be
// chained for wider comparisons; the cascade rules below match the datasheet.
//
// Cascade logic per datasheet truth table:
//   - If A > B (numerically), then a_gt_b=1, a_eq_b=0, a_lt_b=0
//   - If A < B,                a_gt_b=0, a_eq_b=0, a_lt_b=1
//   - If A == B, outputs follow the cascade inputs:
//        a_gt_b = i_a_gt_b
//        a_lt_b = i_a_lt_b
//        a_eq_b = i_a_eq_b
//
// When using a single comparator, tie i_a_eq_b=1, i_a_gt_b=0, i_a_lt_b=0.
// =============================================================================

module ttl_74x85 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    input  logic       i_a_gt_b,
    input  logic       i_a_eq_b,
    input  logic       i_a_lt_b,
    output logic       a_gt_b,
    output logic       a_eq_b,
    output logic       a_lt_b
);
    always_comb begin
        if (a > b) begin
            a_gt_b = 1'b1;
            a_eq_b = 1'b0;
            a_lt_b = 1'b0;
        end else if (a < b) begin
            a_gt_b = 1'b0;
            a_eq_b = 1'b0;
            a_lt_b = 1'b1;
        end else begin
            a_gt_b = ~i_a_lt_b & ~i_a_eq_b;
            a_eq_b = i_a_eq_b;
            a_lt_b = ~i_a_gt_b & ~i_a_eq_b;
        end
    end
endmodule

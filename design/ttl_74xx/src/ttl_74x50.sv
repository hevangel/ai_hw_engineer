// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x50 - Dual 2-2-input AND-OR-Invert gate, one gate expandable.
//
// y[i] = ~((a1[i] & b1[i]) | (a2[i] & b2[i]))    for i in 0..1
//
// =============================================================================

module ttl_74x50 (
    input  logic [1:0] a1,
    input  logic [1:0] b1,
    input  logic [1:0] a2,
    input  logic [1:0] b2,
    input  logic x, // active-high expansion term; tie 0 when unused
    output logic [1:0] y
);
    assign y = ~((a1 & b1) | (a2 & b2) | {1'b0, x});
endmodule

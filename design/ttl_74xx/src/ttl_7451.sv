// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_7451 - Dual 2-2-input AND-OR-Invert (AOI) gate
//
// y[i] = ~((a1[i] & b1[i]) | (a2[i] & b2[i]))    for i in 0..1
// Same logic as 74x50 without expander pins.
// =============================================================================

module ttl_7451 (
    input  logic [1:0] a1,
    input  logic [1:0] b1,
    input  logic [1:0] a2,
    input  logic [1:0] b2,
    output logic [1:0] y
);
    assign y = ~((a1 & b1) | (a2 & b2));
endmodule

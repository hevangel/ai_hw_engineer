// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x55 - 4-4-input AND-OR-Invert gate
//
// y = ~((a1 & b1 & c1 & d1) | (a2 & b2 & c2 & d2))
//
// =============================================================================

module ttl_74x55 (
    input  logic a1, b1, c1, d1,
    input  logic a2, b2, c2, d2,
    input  logic x, // active-high expansion term; tie 0 when unused
    output logic y
);
    assign y = ~((a1 & b1 & c1 & d1) | (a2 & b2 & c2 & d2) | x);
endmodule

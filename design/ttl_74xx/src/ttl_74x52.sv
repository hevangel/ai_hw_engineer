// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x52 - 3-2-2-2-input AND-OR gate, expandable with 74x61
//
// y = (a1 & b1 & c1) | (a2 & b2) | (a3 & b3) | (a4 & b4)
// =============================================================================

module ttl_74x52 (
    input  logic a1, b1, c1,
    input  logic a2, b2,
    input  logic a3, b3,
    input  logic a4, b4,
    input  logic x, // active-high expansion term; tie 0 when unused
    output logic y
);
    assign y = (a1 & b1 & c1) | (a2 & b2) | (a3 & b3) | (a4 & b4) | x;
endmodule

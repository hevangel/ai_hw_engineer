// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x231 - Dual 4-bit inverting buffer/driver; one positive and one negative enable.
module ttl_74x231 (
    input  logic [3:0] a, b,
    input  logic       oe_a_n,     // active low
    input  logic       oe_b,       // active high
    output logic [3:0] ya, yb
);
    assign ya = oe_a_n ? 4'h0 : ~a;
    assign yb = oe_b   ? ~b    : 4'h0;
endmodule

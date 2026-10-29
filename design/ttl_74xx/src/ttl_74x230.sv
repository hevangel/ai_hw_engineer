// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x230 - Dual 4-bit buffer/driver, one inverted, one non-inverted, negative enable.
module ttl_74x230 (
    input  logic [3:0] a, b,
    input  logic [1:0] oe_n,
    output logic [3:0] ya, yb
);
    assign ya = oe_n[0] ? 4'h0 :  a;   // non-inverted
    assign yb = oe_n[1] ? 4'h0 : ~b;   // inverted
endmodule

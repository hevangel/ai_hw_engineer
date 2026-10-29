// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x58 - 3-3 AND-OR + 2-2 AND-OR (non-inverting).
// y[0] = (a1 & b1 & c1) | (a2 & b2 & c2)
// y[1] = (d1 & e1) | (d2 & e2)
module ttl_74x58 (
    input  logic a1, b1, c1, a2, b2, c2,
    input  logic d1, e1, d2, e2,
    output logic [1:0] y
);
    assign y[0] = (a1 & b1 & c1) | (a2 & b2 & c2);
    assign y[1] = (d1 & e1) | (d2 & e2);
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x59 - Dual 3-2 AOI.
// y[i] = ~((a3[i] & b3[i] & c3[i]) | (a2[i] & b2[i]))
module ttl_74x59 (
    input  logic [1:0] a3, b3, c3,
    input  logic [1:0] a2, b2,
    output logic [1:0] y
);
    assign y = ~((a3 & b3 & c3) | (a2 & b2));
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74131 - Quad 2-input AND gate (vendor variant of 74x08).
module ttl_74131 (
    input  logic [3:0] a, b,
    output logic [3:0] y
);
    assign y = a & b;
endmodule

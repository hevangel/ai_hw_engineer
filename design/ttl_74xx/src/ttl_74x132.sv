// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x132 - Quad 2-input NAND with Schmitt-trigger inputs.
// Same logic as 74x00. Schmitt input hysteresis not modeled.
module ttl_74x132 (
    input  logic [3:0] a, b,
    output logic [3:0] y
);
    assign y = ~(a & b);
endmodule

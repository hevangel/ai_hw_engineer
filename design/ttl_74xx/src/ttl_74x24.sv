// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x24 - Quad 2-input NAND, Schmitt-trigger inputs.
// Same logic as 74x00. Schmitt hysteresis not modeled.
module ttl_74x24 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] y
);
    assign y = ~(a & b);
endmodule

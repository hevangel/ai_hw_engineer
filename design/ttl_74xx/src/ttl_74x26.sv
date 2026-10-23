// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x26 - Quad 2-input NAND, OC HV interface gate (15 V).
// Same logic as 74x00. OC + HV drive not modeled.
module ttl_74x26 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] y
);
    assign y = ~(a & b);
endmodule

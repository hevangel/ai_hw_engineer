// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x40 - Dual 4-input NAND buffer/driver.
// Same logic as 74x20. Higher drive not modeled.
module ttl_74x40 (
    input  logic [1:0] a,
    input  logic [1:0] b,
    input  logic [1:0] c,
    input  logic [1:0] d,
    output logic [1:0] y
);
    assign y = ~(a & b & c & d);
endmodule

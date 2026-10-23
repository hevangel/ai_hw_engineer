// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x140 - Dual 4-input NAND line driver (high drive).
// Same logic as 74x20; drive characteristics not modeled.
module ttl_74x140 (
    input  logic [1:0] a, b, c, d,
    output logic [1:0] y
);
    assign y = ~(a & b & c & d);
endmodule

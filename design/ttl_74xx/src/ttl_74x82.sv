// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x82 - 2-bit binary full adder.
// {c2, s} = a + b + c0
module ttl_74x82 (
    input  logic [1:0] a,
    input  logic [1:0] b,
    input  logic       c0,
    output logic [1:0] s,
    output logic       c2
);
    logic [2:0] r;
    assign r = {1'b0, a} + {1'b0, b} + {2'b0, c0};
    assign s  = r[1:0];
    assign c2 = r[2];
endmodule

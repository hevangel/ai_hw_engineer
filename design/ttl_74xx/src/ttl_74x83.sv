// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x83 - 4-bit binary full adder with fast carry
//
// Sum = A + B + Cin   (4-bit, with carry-in c0 and carry-out c4)
// {c4, sum} = {1'b0, a} + {1'b0, b} + c0
// =============================================================================

module ttl_74x83 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    input  logic       c0,
    output logic [3:0] sum,
    output logic       c4
);
    logic [4:0] add;
    assign add = {1'b0, a} + {1'b0, b} + {4'b0000, c0};
    assign sum = add[3:0];
    assign c4  = add[4];
endmodule

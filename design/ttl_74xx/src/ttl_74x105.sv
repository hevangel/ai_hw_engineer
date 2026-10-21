// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x105 - JK master-slave flip-flop, J2 and K2 inverted.
// Effective J = j1 & ~j2, K = k1 & ~k2.
module ttl_74x105 (
    input  logic clk,
    input  logic j1, j2,
    input  logic k1, k2,
    output logic q,
    output logic q_n
);
    logic j, k, q_reg;
    assign j = j1 & ~j2;
    assign k = k1 & ~k2;
    always_ff @(posedge clk) begin
        case ({j, k})
            2'b01: q_reg <= 1'b0;
            2'b10: q_reg <= 1'b1;
            2'b11: q_reg <= ~q_reg;
            default: ;
        endcase
    end
    assign q   = q_reg;
    assign q_n = ~q_reg;
endmodule

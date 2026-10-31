// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x117 - AND-gated JK flip-flop, one J and one K input inverted.
// J = j1 & ~j2_n, K = k1 & ~k2_n.
module ttl_74x117 (
    input  logic clk,
    input  logic j1, j2_n,
    input  logic k1, k2_n,
    output logic q,
    output logic q_n
);
    logic j, k, q_reg;
    assign j = j1 & ~j2_n;
    assign k = k1 & ~k2_n;
    always_ff @(posedge clk) begin
        case ({j, k})
            2'b01: q_reg <= 1'b0;
            2'b10: q_reg <= 1'b1;
            2'b11: q_reg <= ~q_reg;
            default: ;
        endcase
    end
    assign q = q_reg;
    assign q_n = ~q_reg;
endmodule

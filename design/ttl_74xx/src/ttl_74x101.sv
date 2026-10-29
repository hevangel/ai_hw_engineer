// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x101 - AND-OR-gated J-K negedge FF, preset.
// J = (j1a & j1b) | (j2a & j2b), K = (k1a & k1b) | (k2a & k2b)
module ttl_74x101 (
    input  logic clk,
    input  logic j1a, j1b, j2a, j2b,
    input  logic k1a, k1b, k2a, k2b,
    input  logic pre_n,
    output logic q,
    output logic q_n
);
    logic j, k, q_reg;
    assign j = (j1a & j1b) | (j2a & j2b);
    assign k = (k1a & k1b) | (k2a & k2b);
    always_ff @(negedge clk or negedge pre_n) begin
        if (!pre_n) q_reg <= 1'b1;
        else case ({j, k})
            2'b01: q_reg <= 1'b0;
            2'b10: q_reg <= 1'b1;
            2'b11: q_reg <= ~q_reg;
            default: ;
        endcase
    end
    assign q   = q_reg;
    assign q_n = ~q_reg;
endmodule

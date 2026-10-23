// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x72 - AND-gated JK master-slave FF, async preset and clear.
// Same shape as 74x67 but single inputs (no triple-AND). 74x72 has just J
// and K as single inputs.
module ttl_74x72 (
    input  logic clk,
    input  logic j,
    input  logic k,
    input  logic clr_n,
    input  logic pre_n,
    output logic q,
    output logic q_n
);
    logic q_reg;
    always_ff @(posedge clk or negedge clr_n or negedge pre_n) begin
        if (!clr_n)      q_reg <= 1'b0;
        else if (!pre_n) q_reg <= 1'b1;
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

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x67 - AND-gated JK master-slave flip-flop, async preset and clear.
// Inputs J = j1&j2&j3, K = k1&k2&k3. Synthesized as posedge JK FF for FPGA.
module ttl_74x67 (
    input  logic clk,
    input  logic j1, j2, j3,
    input  logic k1, k2, k3,
    input  logic clr_n,
    input  logic pre_n,
    output logic q,
    output logic q_n
);
    logic j, k, q_reg;
    assign j = j1 & j2 & j3;
    assign k = k1 & k2 & k3;
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

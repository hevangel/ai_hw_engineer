// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74l71 - AND-gated R-S master-slave FF, preset and clear.
// R = r1 & r2 & r3, S = s1 & s2 & s3
// R=1: q->0; S=1: q->1; R=S=1: invalid (Q=1 by priority).
module ttl_74l71 (
    input  logic clk,
    input  logic s1, s2, s3,
    input  logic r1, r2, r3,
    input  logic pre_n,
    input  logic clr_n,
    output logic q,
    output logic q_n
);
    logic s, r, q_reg;
    assign s = s1 & s2 & s3;
    assign r = r1 & r2 & r3;
    always_ff @(posedge clk or negedge pre_n or negedge clr_n) begin
        if (!clr_n)      q_reg <= 1'b0;
        else if (!pre_n) q_reg <= 1'b1;
        else if (s)      q_reg <= 1'b1;
        else if (r)      q_reg <= 1'b0;
    end
    assign q   = q_reg;
    assign q_n = ~q_reg;
endmodule

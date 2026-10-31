// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x179 - 4-bit parallel-access shift register with async clear, complementary outputs.
module ttl_74x179 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic       s_l,
    input  logic       shift_en,
    input  logic       din,
    input  logic [3:0] p,
    output logic [3:0] q,
    output logic [3:0] q_n
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n)         q <= 4'h0;
        else if (s_l)       q <= p;
        else if (shift_en)  q <= {din, q[3:1]};
    end
    assign q_n = ~q;
endmodule

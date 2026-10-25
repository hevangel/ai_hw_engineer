// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x195 - 4-bit parallel-access shift register with j/k serial inputs.
// When sh_ld_n=0: parallel load p.
// When sh_ld_n=1: shift right with new bit = j & ~q[3] | ~k & q[3] (JK).
// Async clear.
module ttl_74x195 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic       sh_ld_n,
    input  logic       j,
    input  logic       k_n,         // /K input
    input  logic [3:0] p,
    output logic [3:0] q,
    output logic       q3_n
);
    logic next_msb;
    assign next_msb = (j & ~q[3]) | (~k_n & q[3]);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n)        q <= 4'h0;
        else if (!sh_ld_n) q <= p;
        else               q <= {next_msb, q[3:1]};
    end
    assign q3_n = ~q[3];
endmodule

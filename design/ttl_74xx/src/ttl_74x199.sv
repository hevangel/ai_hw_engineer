// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x199 - 8-bit universal shift register with J-/K serial inputs.
module ttl_74x199 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic       sh_ld_n,
    input  logic       j,
    input  logic       k_n,
    input  logic [7:0] p,
    output logic [7:0] q
);
    logic next_msb;
    assign next_msb = (j & ~q[7]) | (~k_n & q[7]);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n)        q <= 8'h00;
        else if (!sh_ld_n) q <= p;
        else               q <= {next_msb, q[7:1]};
    end
endmodule

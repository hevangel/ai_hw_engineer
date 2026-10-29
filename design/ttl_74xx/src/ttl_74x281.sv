// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x281 - 4-bit parallel binary accumulator.
// On posedge clk: q <= q + d (with carry in / carry out).
module ttl_74x281 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic [3:0] d,
    input  logic       cin,
    output logic [3:0] q,
    output logic       cout
);
    logic [4:0] sum;
    assign sum = {1'b0, q} + {1'b0, d} + {4'b0, cin};
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) q <= 4'h0;
        else        q <= sum[3:0];
    end
    assign cout = sum[4];
endmodule

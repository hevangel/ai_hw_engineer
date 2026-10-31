// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x98 - 4-bit data selector / storage register.
// On posedge clk, q <= select ? b : a.
// Async clear.
module ttl_74x98 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic       select,
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] q
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) q <= 4'h0;
        else        q <= select ? b : a;
    end
endmodule

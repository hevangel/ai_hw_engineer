// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x273 - Octal D-type flip-flop with asynchronous clear
//
// Eight posedge-triggered D flip-flops, common clock, common active-low
// async clear. No output enable (use 74x374 for that).
// =============================================================================

module ttl_74x273 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic [7:0] d,
    output logic [7:0] q
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) q <= 8'h00;
        else        q <= d;
    end
endmodule

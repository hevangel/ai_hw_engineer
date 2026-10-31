// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x174 - Hex D-type flip-flop with common clock and asynchronous clear
//
// Six posedge-triggered D flip-flops sharing one clock and one async
// active-low clear. No /Q outputs (use 74x175 if you need them).
// =============================================================================

module ttl_74x174 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic [5:0] d,
    output logic [5:0] q
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) q <= 6'b000000;
        else        q <= d;
    end
endmodule

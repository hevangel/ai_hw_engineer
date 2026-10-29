// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x56 - 50:1 frequency divider
//
// Divides input clock by 50. Counter resets to 0 and increments on each
// clock edge; output toggles when reaching 25 (giving 50:1 frequency division
// with 50% duty cycle).
// =============================================================================

module ttl_74x56 (
    input  logic clk,
    input  logic clr_n,
    output logic q
);
    logic [5:0] cnt;

    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) begin
            cnt <= 6'd0;
            q   <= 1'b0;
        end else if (cnt == 6'd24) begin
            cnt <= 6'd0;
            q   <= ~q;
        end else begin
            cnt <= cnt + 6'd1;
        end
    end
endmodule

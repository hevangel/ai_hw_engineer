// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x57 - 60:1 frequency divider. Like 74x56 but divides by 60.
module ttl_74x57 (
    input  logic clk,
    input  logic clr_n,
    output logic q
);
    logic [5:0] cnt;

    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) begin
            cnt <= 6'd0;
            q   <= 1'b0;
        end else if (cnt == 6'd29) begin
            cnt <= 6'd0;
            q   <= ~q;
        end else begin
            cnt <= cnt + 6'd1;
        end
    end
endmodule

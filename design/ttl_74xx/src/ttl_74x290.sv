// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x290 - Decade counter (functionally identical to 74x90).
module ttl_74x290 (
    input  logic clk_a, clk_b,
    input  logic r0_1, r0_2,
    input  logic r9_1, r9_2,
    output logic q_a, q_b, q_c, q_d
);
    logic reset, set9;
    logic [2:0] cnt5;
    assign reset = r0_1 & r0_2;
    assign set9  = r9_1 & r9_2;
    always_ff @(negedge clk_a or posedge reset or posedge set9) begin
        if (set9)       q_a <= 1'b1;
        else if (reset) q_a <= 1'b0;
        else            q_a <= ~q_a;
    end
    always_ff @(negedge clk_b or posedge reset or posedge set9) begin
        if (set9)               cnt5 <= 3'b100;
        else if (reset)         cnt5 <= 3'b000;
        else if (cnt5 == 3'b100) cnt5 <= 3'b000;
        else                    cnt5 <= cnt5 + 3'b001;
    end
    assign q_b = cnt5[0];
    assign q_c = cnt5[1];
    assign q_d = cnt5[2];
endmodule

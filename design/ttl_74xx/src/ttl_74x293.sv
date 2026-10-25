// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x293 - 4-bit binary counter (same as 74x93).
module ttl_74x293 (
    input  logic clk_a, clk_b,
    input  logic r0_1, r0_2,
    output logic q_a, q_b, q_c, q_d
);
    logic reset;
    logic [2:0] cnt8;
    assign reset = r0_1 & r0_2;
    always_ff @(negedge clk_a or posedge reset) begin
        if (reset) q_a <= 1'b0;
        else       q_a <= ~q_a;
    end
    always_ff @(negedge clk_b or posedge reset) begin
        if (reset) cnt8 <= 3'b000;
        else       cnt8 <= cnt8 + 3'b001;
    end
    assign q_b = cnt8[0];
    assign q_c = cnt8[1];
    assign q_d = cnt8[2];
endmodule

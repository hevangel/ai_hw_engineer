// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x92 - Divide-by-12 counter (÷2 and ÷6 sections)
//
// Section A: ÷2 toggled by clk_a
// Section B: ÷6 (3-bit mod-6 counter) clocked by clk_b
// Reset: r0_1 & r0_2 (active high pair) asynchronously clears all.
// =============================================================================

module ttl_74x92 (
    input  logic clk_a,
    input  logic clk_b,
    input  logic r0_1, r0_2,
    output logic q_a,
    output logic q_b,
    output logic q_c,
    output logic q_d
);
    logic reset;
    logic [2:0] cnt6;
    assign reset = r0_1 & r0_2;

    always_ff @(negedge clk_a or posedge reset) begin
        if (reset) q_a <= 1'b0;
        else       q_a <= ~q_a;
    end

    always_ff @(negedge clk_b or posedge reset) begin
        if (reset)              cnt6 <= 3'b000;
        else begin
            case (cnt6)
                3'b000: cnt6 <= 3'b001;
                3'b001: cnt6 <= 3'b010;
                3'b010: cnt6 <= 3'b100;
                3'b100: cnt6 <= 3'b101;
                3'b101: cnt6 <= 3'b110;
                default: cnt6 <= 3'b000;
            endcase
        end
    end

    assign q_b = cnt6[0];
    assign q_c = cnt6[1];
    assign q_d = cnt6[2];
endmodule

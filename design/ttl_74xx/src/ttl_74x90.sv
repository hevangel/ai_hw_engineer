// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x90 - Decade counter (separate ÷2 and ÷5 sections)
//
// Two independent counter sections:
//   - Section A: 1-bit toggle on clk_a (÷2)
//   - Section B: mod-5 counter on clk_b (÷5)
// Cascade externally by tying QA -> CKB for full ÷10.
//
// Reset/set inputs:
//   r0_1 & r0_2 (both 1): asynchronous reset to 0
//   r9_1 & r9_2 (both 1): asynchronous set to 9 (QA=1, QB=0, QC=0, QD=1)
// r9 has priority over r0 per datasheet.
// =============================================================================

module ttl_74x90 (
    input  logic clk_a,
    input  logic clk_b,
    input  logic r0_1, r0_2,
    input  logic r9_1, r9_2,
    output logic q_a,
    output logic q_b,
    output logic q_c,
    output logic q_d
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
        if (set9)            cnt5 <= 3'b100; // QB=0, QC=0, QD=1 -> value 4 in this 3-bit form
        else if (reset)      cnt5 <= 3'b000;
        else if (cnt5 == 3'b100) cnt5 <= 3'b000;
        else                 cnt5 <= cnt5 + 3'b001;
    end

    assign q_b = cnt5[0];
    assign q_c = cnt5[1];
    assign q_d = cnt5[2];
endmodule

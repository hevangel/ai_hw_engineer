// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x196 - Presettable 4-bit decade counter/latch.
// Similar to 74x176.
module ttl_74x196 (
    input  logic       clk_a,
    input  logic       clk_b,
    input  logic       clr_n,
    input  logic       load_n,
    input  logic [3:0] d,
    output logic       q_a,
    output logic       q_b,
    output logic       q_c,
    output logic       q_d
);
    logic [2:0] cnt5;
    always_ff @(posedge clk_a or negedge clr_n or negedge load_n) begin
        if (!clr_n)       q_a <= 1'b0;
        else if (!load_n) q_a <= d[0];
        else              q_a <= ~q_a;
    end
    always_ff @(posedge clk_b or negedge clr_n or negedge load_n) begin
        if (!clr_n)              cnt5 <= 3'b000;
        else if (!load_n)        cnt5 <= d[3:1];
        else if (cnt5 == 3'b100) cnt5 <= 3'b000;
        else                     cnt5 <= cnt5 + 3'b001;
    end
    assign q_b = cnt5[0];
    assign q_c = cnt5[1];
    assign q_d = cnt5[2];
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x299 - 8-bit bidirectional universal shift/storage register, 3-state.
module ttl_74x299 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic       oe_n,
    input  logic       s0, s1,
    input  logic       din_right,
    input  logic       din_left,
    input  logic [7:0] p,
    output logic [7:0] q,
    output logic [7:0] drive_en,
    output logic q0, q7
);
    logic [7:0] sr;
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) sr <= 8'h00;
        else case ({s1, s0})
            2'b00: ;
            2'b01: sr <= {din_right, sr[7:1]};
            2'b10: sr <= {sr[6:0], din_left};
            2'b11: sr <= p;
        endcase
    end
    assign q = oe_n ? 8'h00 : sr;
    assign drive_en = {8{~oe_n & ~(s0 & s1)}};
    assign q0 = sr[0];
    assign q7 = sr[7];
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x194 - 4-bit bidirectional universal shift register (same as 74x99).
module ttl_74x194 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic       s0, s1,
    input  logic       din_right,
    input  logic       din_left,
    input  logic [3:0] p,
    output logic [3:0] q
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) q <= 4'h0;
        else case ({s1, s0})
            2'b00: ;
            2'b01: q <= {din_right, q[3:1]};
            2'b10: q <= {q[2:0], din_left};
            2'b11: q <= p;
        endcase
    end
endmodule

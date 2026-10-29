// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x198 - 8-bit bidirectional universal shift register.
module ttl_74x198 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic       s0, s1,
    input  logic       din_right,
    input  logic       din_left,
    input  logic [7:0] p,
    output logic [7:0] q
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) q <= 8'h00;
        else case ({s1, s0})
            2'b00: ;
            2'b01: q <= {din_right, q[7:1]};
            2'b10: q <= {q[6:0], din_left};
            2'b11: q <= p;
        endcase
    end
endmodule

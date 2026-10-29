// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x226 - 4-bit parallel latched bus transceiver.
// 4-bit bidirectional bus with internal latches in each direction.
module ttl_74x226 (
    input  logic       clk,
    input  logic       dir,        // 1 = A->B, 0 = B->A
    input  logic       oe_n,
    input  logic [3:0] a_in, b_in,
    output logic [3:0] a_out, b_out,
    output logic       a_oe_n, b_oe_n
);
    logic [3:0] a_latch, b_latch;
    always_ff @(posedge clk) begin
        if (dir) a_latch <= a_in;
        else     b_latch <= b_in;
    end
    always_comb begin
        if (oe_n) begin
            a_out = 4'h0; b_out = 4'h0; a_oe_n = 1; b_oe_n = 1;
        end else if (dir) begin
            b_out = a_latch; a_out = 4'h0; b_oe_n = 0; a_oe_n = 1;
        end else begin
            a_out = b_latch; b_out = 4'h0; a_oe_n = 0; b_oe_n = 1;
        end
    end
endmodule

// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74450.md.
// ttl_74450 - Counter + latch + 7-seg decoder (same shape as 74x143).
module ttl_74450 (
    input  logic clk, clr_n, le,
    output logic [6:0] seg,
    output logic c_n
);
    logic [3:0] cnt, latch_q;
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n)        cnt <= 0;
        else if (cnt == 9) cnt <= 0;
        else               cnt <= cnt + 1;
    end
    always_latch begin if (le) latch_q = cnt; end
    always_comb begin
        case (latch_q)
            4'd0: seg = 7'b1111110;
            4'd1: seg = 7'b0110000;
            4'd2: seg = 7'b1101101;
            4'd3: seg = 7'b1111001;
            4'd4: seg = 7'b0110011;
            4'd5: seg = 7'b1011011;
            4'd6: seg = 7'b0011111;
            4'd7: seg = 7'b1110000;
            4'd8: seg = 7'b1111111;
            4'd9: seg = 7'b1110011;
            default: seg = 7'b0000000;
        endcase
    end
    assign c_n = ~(cnt == 9);
endmodule

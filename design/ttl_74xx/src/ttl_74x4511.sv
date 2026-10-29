// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4511.md.
// ttl_74x4511 - BCD to 7-segment latch/decoder/driver.
// le_n: latch enable (low=transparent); bl_n: blank (low=force all segs off);
// lt_n: lamp test (low=force all segs on).
module ttl_74x4511 (
    input  logic       le_n, bl_n, lt_n,
    input  logic [3:0] d,
    output logic [6:0] seg            // a..g (active high)
);
    logic [3:0] q;
    always_latch if (!le_n) q = d;
    always_comb begin
        if (!lt_n)      seg = 7'b1111111;
        else if (!bl_n) seg = 7'b0000000;
        else case (q)
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
endmodule

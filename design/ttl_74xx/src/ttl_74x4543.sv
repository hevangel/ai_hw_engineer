// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4543.md.
// ttl_74x4543 - BCD to 7-segment latch/decoder/driver for LCDs.
// le_n: latch enable (low=transparent); bl: blank (high=blank);
// ph: phase (XOR'd with each segment for LCD AC drive).
module ttl_74x4543 (
    input  logic       le_n, bl, ph,
    input  logic [3:0] d,
    output logic [6:0] seg
);
    logic [3:0] q;
    logic [6:0] decoded;
    always_latch if (!le_n) q = d;
    always_comb begin
        case (q)
            4'd0: decoded = 7'b1111110;
            4'd1: decoded = 7'b0110000;
            4'd2: decoded = 7'b1101101;
            4'd3: decoded = 7'b1111001;
            4'd4: decoded = 7'b0110011;
            4'd5: decoded = 7'b1011011;
            4'd6: decoded = 7'b0011111;
            4'd7: decoded = 7'b1110000;
            4'd8: decoded = 7'b1111111;
            4'd9: decoded = 7'b1110011;
            default: decoded = 7'b0000000;
        endcase
        seg = bl ? 7'b0 : (decoded ^ {7{ph}});
    end
endmodule

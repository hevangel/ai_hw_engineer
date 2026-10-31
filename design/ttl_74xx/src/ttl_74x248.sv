// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x248 - BCD-to-7-seg, active-high outputs, rounded 6/9.
// Same shape as 74x48 with rounded segment patterns for 6 and 9.
module ttl_74x248 (
    input  logic [3:0] bcd,
    input  logic       lt_n,
    input  logic       bi_n,
    input  logic       rbi_n,
    output logic [6:0] seg,
    output logic       rbo_n
);
    logic [6:0] seg_ah;
    logic       blank, lamp_test;
    always_comb begin
        case (bcd)
            4'h0: seg_ah = 7'b1111110;
            4'h1: seg_ah = 7'b0110000;
            4'h2: seg_ah = 7'b1101101;
            4'h3: seg_ah = 7'b1111001;
            4'h4: seg_ah = 7'b0110011;
            4'h5: seg_ah = 7'b1011011;
            4'h6: seg_ah = 7'b1011111;
            4'h7: seg_ah = 7'b1110000;
            4'h8: seg_ah = 7'b1111111;
            4'h9: seg_ah = 7'b1111011;
            default: seg_ah = 7'b0000000;
        endcase
        lamp_test = (bi_n == 1'b1) && (lt_n == 1'b0);
        blank     = (bi_n == 1'b0) ||
                    ((bi_n == 1'b1) && (lt_n == 1'b1) && (rbi_n == 1'b0) && (bcd == 4'h0));
        if (lamp_test)     begin seg = 7'b1111111; rbo_n = 1'b1; end
        else if (blank)    begin seg = 7'b0000000; rbo_n = 1'b0; end
        else               begin seg = seg_ah;     rbo_n = 1'b1; end
    end
endmodule

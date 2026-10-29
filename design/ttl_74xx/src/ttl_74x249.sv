// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x249 - BCD-to-7-seg, OC, rounded 6/9 with BI only (no LT/RBI).
module ttl_74x249 (
    input  logic [3:0] bcd,
    input  logic       bi_n,
    output logic [6:0] seg
);
    logic [6:0] seg_ah;
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
        seg = bi_n ? seg_ah : 7'b0000000;
    end
endmodule

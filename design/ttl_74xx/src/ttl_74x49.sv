// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x49 - BCD to 7-segment decoder/driver, OC, active-high outputs
//
// Simpler than 74x47/74x48: only a single blanking input (bi_n, active low).
// No lamp test, no ripple blanking. Segment decode for 0..9 matches 7448;
// for 0xA..0xF, the chip produces the same "partial patterns" as 7447/7448.
//
// Output polarity: real 7449 has active-HIGH OC outputs (off when sinking).
// OC drive characteristics are not modeled.
// =============================================================================

module ttl_74x49 (
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
            4'h6: seg_ah = 7'b0011111;
            4'h7: seg_ah = 7'b1110000;
            4'h8: seg_ah = 7'b1111111;
            4'h9: seg_ah = 7'b1110011;
            4'hA: seg_ah = 7'b0001101;
            4'hB: seg_ah = 7'b0011001;
            4'hC: seg_ah = 7'b0100011;
            4'hD: seg_ah = 7'b1001011;
            4'hE: seg_ah = 7'b0001111;
            4'hF: seg_ah = 7'b0000000;
            default: seg_ah = 7'b0000000;
        endcase

        seg = bi_n ? seg_ah : 7'b0000000;
    end

endmodule

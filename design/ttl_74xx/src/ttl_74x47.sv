// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x47 - BCD to 7-segment decoder/driver, OC 15 V, active-low outputs
//
// Inputs:
//   bcd[3:0]  : BCD value (0..15)
//   lt_n      : Lamp test, active low. When 0 and bi_n=1, all segments lit.
//   bi_n      : Blanking input, active low. When 0, all segments off and rbo_n=0.
//   rbi_n     : Ripple blanking input, active low. When 0 AND bcd=0, blank
//               the digit AND drive rbo_n low.
// Outputs:
//   seg_n[6:0]: Segment outputs in order {a, b, c, d, e, f, g}, active low.
//   rbo_n     : Ripple blanking output, active low. On the real chip rbo_n
//               and bi_n share a single bidirectional pin.
//
// Priority (per SN7447A datasheet, table I):
//   1) bi_n=0       -> all segments off, rbo_n=0
//   2) lt_n=0       -> all segments lit, rbo_n=1   (test mode)
//   3) rbi_n=0 AND bcd=0 -> all segments off, rbo_n=0  (ripple blanking)
//   4) otherwise    -> standard decode, rbo_n=1
//
// Decode patterns (active-high in internal seg variable, then inverted to seg_n):
//   0 -> abcdef     5 -> acdfg     A -> defg     E -> adefg
//   1 -> bc         6 -> cdefg     B -> cdg
//   2 -> abdeg      7 -> abc       C -> adfg     F -> (blank)
//   3 -> abcdg      8 -> abcdefg   D -> bdeg
//   4 -> bcfg       9 -> abcdfg
// =============================================================================

module ttl_74x47 (
    input  logic [3:0] bcd,
    input  logic       lt_n,
    input  logic       bi_n,
    input  logic       rbi_n,
    output logic [6:0] seg_n,
    output logic       rbo_n
);

    logic [6:0] seg_ah; // active-high segments
    logic       blank;
    logic       lamp_test;

    always_comb begin
        // Decode pattern by hex value, active-high.
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

        // Resolve blanking/lamp-test priority (datasheet truth table).
        // bi_n=0 has highest priority and forces blank.
        // lt_n=0 (with bi_n=1) forces all lit.
        // rbi_n=0 with bcd=0 forces blank and pulls rbo_n low.
        // Otherwise normal decode.
        lamp_test = (bi_n == 1'b1) && (lt_n == 1'b0);
        blank     = (bi_n == 1'b0) ||
                    ((bi_n == 1'b1) && (lt_n == 1'b1) && (rbi_n == 1'b0) && (bcd == 4'h0));

        if (lamp_test) begin
            seg_n = 7'b0000000;       // all lit (active-low outputs all = 0)
            rbo_n = 1'b1;
        end else if (blank) begin
            seg_n = 7'b1111111;       // all blank
            rbo_n = 1'b0;             // ripple-blanking out
        end else begin
            seg_n = ~seg_ah;          // normal decode, invert for active-low
            rbo_n = 1'b1;
        end
    end

endmodule

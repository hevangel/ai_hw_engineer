// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x42 - BCD-to-decimal decoder (1-of-10), active-low outputs
//
// 4-bit BCD input (bcd[3]=A3=MSB, bcd[0]=A0=LSB). Ten active-low outputs.
// For inputs 0..9, the corresponding output goes low and all others stay high.
// For inputs 10..15 (invalid BCD), all outputs stay high.
//
// Datasheet: TI SN74LS42.
// =============================================================================

module ttl_74x42 (
    input  logic [3:0] bcd,
    output logic [9:0] y_n
);

    always_comb begin
        y_n = 10'b1111111111;
        if (bcd < 4'd10) begin
            y_n[bcd] = 1'b0;
        end
    end

endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x44 - Gray-code (excess-3 Gray) to decimal decoder, active-low outputs
//
// The 74x44 maps a 4-bit "excess-3 Gray code" input to one of ten active-low
// decimal outputs. The mapping from input code to decimal value, per the
// datasheet:
//
//   Gray  Dec
//   0010  0
//   0110  1
//   0111  2
//   0101  3
//   0100  4
//   1100  5
//   1101  6
//   1111  7
//   1110  8
//   1010  9
//
// All other inputs leave all outputs high (no decode).
// =============================================================================

module ttl_74x44 (
    input  logic [3:0] g,
    output logic [9:0] y_n
);

    always_comb begin
        y_n = 10'b1111111111;
        case (g)
            4'b0010: y_n[0] = 1'b0;
            4'b0110: y_n[1] = 1'b0;
            4'b0111: y_n[2] = 1'b0;
            4'b0101: y_n[3] = 1'b0;
            4'b0100: y_n[4] = 1'b0;
            4'b1100: y_n[5] = 1'b0;
            4'b1101: y_n[6] = 1'b0;
            4'b1111: y_n[7] = 1'b0;
            4'b1110: y_n[8] = 1'b0;
            4'b1010: y_n[9] = 1'b0;
            default: /* all high */ ;
        endcase
    end

endmodule

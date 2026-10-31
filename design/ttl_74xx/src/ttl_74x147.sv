// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x147 - 10-to-4 priority encoder (decimal to BCD)
//
// Active-low inputs i_n[9:1] (no i_n[0] — input 0 is implicit). Active-low
// BCD outputs y_n[3:0] (so output reads "9" with active-low pattern when
// i_n[9]=0).
//
// Priority: highest-numbered asserted input wins.
// =============================================================================

module ttl_74x147 (
    input  logic [9:1] i_n,
    output logic [3:0] y_n
);
    logic [3:0] code;
    always_comb begin
        casez (i_n)
            9'b0????????: code = 4'd9;
            9'b10???????: code = 4'd8;
            9'b110??????: code = 4'd7;
            9'b1110?????: code = 4'd6;
            9'b11110????: code = 4'd5;
            9'b111110???: code = 4'd4;
            9'b1111110??: code = 4'd3;
            9'b11111110?: code = 4'd2;
            9'b111111110: code = 4'd1;
            default:      code = 4'd0;
        endcase
    end
    assign y_n = ~code;
endmodule

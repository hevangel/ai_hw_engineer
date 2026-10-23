// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x149 - 8-to-8 priority encoder.
// Active-low inputs i_n[7:0]. One-hot active-low outputs y_n[7:0] showing
// the highest-priority asserted input.
module ttl_74x149 (
    input  logic [7:0] i_n,
    output logic [7:0] y_n
);
    logic [2:0] sel;
    always_comb begin
        casez (i_n)
            8'b0???????: sel = 3'd7;
            8'b10??????: sel = 3'd6;
            8'b110?????: sel = 3'd5;
            8'b1110????: sel = 3'd4;
            8'b11110???: sel = 3'd3;
            8'b111110??: sel = 3'd2;
            8'b1111110?: sel = 3'd1;
            8'b11111110: sel = 3'd0;
            default:     sel = 3'd0;
        endcase
    end
    always_comb begin
        y_n = 8'hFF;
        if (i_n != 8'hFF) y_n[sel] = 1'b0;
    end
endmodule

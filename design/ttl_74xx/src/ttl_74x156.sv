// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x156 - Dual 2-to-4 decoder, OC (same logic as 74x155).
module ttl_74x156 (
    input  logic [1:0] a,
    input  logic [1:0] g_n,
    input  logic [1:0] c, // section 0 active HIGH; section 1 active LOW
    output logic [3:0] y0_n,
    output logic [3:0] y1_n
);
    always_comb begin
        y0_n = 4'hF;
        y1_n = 4'hF;
        if (!g_n[0] && c[0]) y0_n[a] = 1'b0;
        if (!g_n[1] && !c[1]) y1_n[a] = 1'b0;
    end
endmodule

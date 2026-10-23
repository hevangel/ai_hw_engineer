// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x255 - Dual 2-to-4 decoder, inverting outputs.
module ttl_74x255 (
    input  logic [1:0] g_n,
    input  logic [3:0] a,
    output logic [7:0] y_n,
    output logic [1:0] drive_en
);
    always_comb begin
        y_n = 8'hFF;
        if (!g_n[0]) y_n[{1'b0, a[1:0]}] = 1'b0;
        if (!g_n[1]) y_n[{1'b1, a[3:2]}] = 1'b0;
    end
    assign drive_en = ~g_n;
endmodule

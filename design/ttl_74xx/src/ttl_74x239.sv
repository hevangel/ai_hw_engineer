// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x239 - Dual 2-to-4 decoder/demultiplexer, active-high outputs.
module ttl_74x239 (
    input  logic [1:0] g_n,
    input  logic [3:0] a,
    output logic [7:0] y
);
    always_comb begin
        y = 8'h00;
        if (!g_n[0]) y[{1'b0, a[1:0]}] = 1'b1;
        if (!g_n[1]) y[{1'b1, a[3:2]}] = 1'b1;
    end
endmodule

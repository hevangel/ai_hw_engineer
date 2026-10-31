// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x154 - 4-to-16 line decoder/demultiplexer, inverting outputs.
// Two active-low enables (both must be low to enable).
module ttl_74x154 (
    input  logic [3:0]  a,
    input  logic        g1_n,
    input  logic        g2_n,
    output logic [15:0] y_n
);
    always_comb begin
        y_n = 16'hFFFF;
        if (!g1_n && !g2_n) y_n[a] = 1'b0;
    end
endmodule

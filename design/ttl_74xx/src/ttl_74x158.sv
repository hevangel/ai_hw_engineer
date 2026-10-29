// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x158 - Quad 2-to-1 mux, inverting output. Active-low enable.
module ttl_74x158 (
    input  logic       g_n,
    input  logic       select,
    input  logic [3:0] a, b,
    output logic [3:0] y_n
);
    assign y_n = g_n ? 4'hF : ~(select ? b : a);
endmodule

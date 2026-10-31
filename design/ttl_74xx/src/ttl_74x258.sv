// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x258 - Quad 2-to-1 mux, inverting, 3-state outputs.
module ttl_74x258 (
    input  logic       g_n,
    input  logic       select,
    input  logic [3:0] a, b,
    output logic [3:0] y_n,
    output logic  drive_en
);
    assign y_n = g_n ? 4'h0 : ~(select ? b : a);
    assign drive_en = ~g_n;
endmodule

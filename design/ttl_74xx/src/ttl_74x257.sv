// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x257 - Quad 2-to-1 mux, non-inverting, 3-state outputs.
module ttl_74x257 (
    input  logic       g_n,
    input  logic       select,
    input  logic [3:0] a, b,
    output logic [3:0] y,
    output logic  drive_en
);
    assign y = g_n ? 4'h0 : (select ? b : a);
    assign drive_en = ~g_n;
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x253 - Dual 4-to-1 mux with 3-state outputs.
module ttl_74x253 (
    input  logic [1:0] s,
    input  logic [1:0] g_n,
    input  logic [3:0] d0,
    input  logic [3:0] d1,
    output logic [1:0] y,
    output logic [1:0] drive_en
);
    assign y[0] = g_n[0] ? 1'b0 : d0[s];
    assign y[1] = g_n[1] ? 1'b0 : d1[s];
    assign drive_en = ~g_n;
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x153 - Dual 4-to-1 multiplexer, non-inverting outputs.
// Shared select s[1:0], per-mux enable g_n[1:0] (active low). When g_n[i]=1
// the output is 0.
module ttl_74x153 (
    input  logic [1:0] s,
    input  logic [1:0] g_n,
    input  logic [3:0] d0,
    input  logic [3:0] d1,
    output logic [1:0] y
);
    assign y[0] = g_n[0] ? 1'b0 : d0[s];
    assign y[1] = g_n[1] ? 1'b0 : d1[s];
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x150 - 16-to-1 multiplexer with enable.
// When g_n=0: y = d[s]. When g_n=1: y = 0. Output is inverted on the real chip.
module ttl_74x150 (
    input  logic        g_n,
    input  logic [3:0]  s,
    input  logic [15:0] d,
    output logic        y_n
);
    assign y_n = g_n ? 1'b1 : ~d[s];
endmodule

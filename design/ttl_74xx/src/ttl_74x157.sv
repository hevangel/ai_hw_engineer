// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x157 - Quad 2-to-1 line multiplexer
//
// y[i] = select ? b[i] : a[i]    when g_n=0
// y    = 4'h0                    when g_n=1
//
// g_n is the active-low chip enable. When deasserted, the outputs are
// forced to 0 (in the real chip the outputs are still push-pull, just
// driven low).
// =============================================================================

module ttl_74x157 (
    input  logic       g_n,
    input  logic       select,
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] y
);
    assign y = g_n ? 4'h0 : (select ? b : a);
endmodule

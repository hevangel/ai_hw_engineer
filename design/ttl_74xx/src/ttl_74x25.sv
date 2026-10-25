// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x25 - Dual 4-input NOR gate with strobe.
//
// Same digital function as 74x23 but without the 74x60 expander port:
// Y = ~(G & (A | B | C | D)).
// =============================================================================

module ttl_74x25 (
    input  logic [1:0] a,
    input  logic [1:0] b,
    input  logic [1:0] c,
    input  logic [1:0] d,
    input  logic [1:0] g,
    output logic [1:0] y
);
    assign y = ~(g & (a | b | c | d));
endmodule

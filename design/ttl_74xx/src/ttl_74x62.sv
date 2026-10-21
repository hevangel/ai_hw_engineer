// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x62 - 3-3-2-2 expander for 74x50, 74x53, 74x55.
// Four AND sections of widths 3, 3, 2, 2; output x is OR of all sections
// (since the host AOI gates OR these together internally), and x_n is ~x.
// Digital-only approximation.
module ttl_74x62 (
    input  logic a1, b1, c1,
    input  logic a2, b2, c2,
    input  logic a3, b3,
    input  logic a4, b4,
    output logic x,
    output logic x_n
);
    assign x   =  (a1 & b1 & c1) | (a2 & b2 & c2) | (a3 & b3) | (a4 & b4);
    assign x_n = ~x;
endmodule

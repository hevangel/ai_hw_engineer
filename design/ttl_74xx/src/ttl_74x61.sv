// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x61 - Triple 3-input expander for 74x52.
// Per-section function: x = a & b & c; x_n = ~x.
// Digital-only approximation. See README for context.
module ttl_74x61 (
    input  logic [2:0] a,
    input  logic [2:0] b,
    input  logic [2:0] c,
    output logic [2:0] x,
    output logic [2:0] x_n
);
    assign x   =  a & b & c;
    assign x_n = ~(a & b & c);
endmodule

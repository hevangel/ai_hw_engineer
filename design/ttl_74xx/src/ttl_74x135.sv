// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x135 - Quad XOR/XNOR gate with select.
// Pairs of gates share a select input C: y = a ^ b ^ c.
// (When c=0: y = a^b = XOR; when c=1: y = a^b^1 = XNOR)
module ttl_74x135 (
    input  logic [3:0] a, b,
    input  logic [1:0] c,
    output logic [3:0] y
);
    assign y[0] = a[0] ^ b[0] ^ c[0];
    assign y[1] = a[1] ^ b[1] ^ c[0];
    assign y[2] = a[2] ^ b[2] ^ c[1];
    assign y[3] = a[3] ^ b[3] ^ c[1];
endmodule

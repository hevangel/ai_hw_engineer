// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x64 - 4-3-2-2 AOI gate.
// y = ~((a1&b1&c1&d1) | (a2&b2&c2) | (a3&b3) | (a4&b4))
module ttl_74x64 (
    input  logic a1, b1, c1, d1,
    input  logic a2, b2, c2,
    input  logic a3, b3,
    input  logic a4, b4,
    output logic y
);
    assign y = ~((a1 & b1 & c1 & d1) | (a2 & b2 & c2) | (a3 & b3) | (a4 & b4));
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x266 - Quad 2-input XNOR gate, open-collector.
module ttl_74x266 (
    input  logic [3:0] a, b,
    output logic [3:0] y
);
    assign y = ~(a ^ b);
endmodule

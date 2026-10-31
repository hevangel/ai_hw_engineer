// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x136 - Quad 2-input XOR gate, open-collector.
// Same logic as 74x86; OC physics not modeled.
module ttl_74x136 (
    input  logic [3:0] a, b,
    output logic [3:0] y
);
    assign y = a ^ b;
endmodule

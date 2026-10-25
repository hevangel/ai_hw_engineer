// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x33 - Quad 2-input NOR buffer, open-collector outputs.
// Same logic as 74x02. OC physics not modeled.
module ttl_74x33 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] y
);
    assign y = ~(a | b);
endmodule

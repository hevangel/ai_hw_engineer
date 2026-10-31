// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x128 - Quad 2-input NOR line driver (high drive).
// Same logic as 74x02; higher drive not modeled.
module ttl_74x128 (
    input  logic [3:0] a, b,
    output logic [3:0] y
);
    assign y = ~(a | b);
endmodule

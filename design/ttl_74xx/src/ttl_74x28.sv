// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x28 - Quad 2-input NOR buffer/driver (N=30 fanout).
// Same logic as 74x02; higher drive not modeled.
module ttl_74x28 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] y
);
    assign y = ~(a | b);
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x260 - Dual 5-input NOR gate.
module ttl_74x260 (
    input  logic [1:0] a, b, c, d, e,
    output logic [1:0] y
);
    assign y = ~(a | b | c | d | e);
endmodule

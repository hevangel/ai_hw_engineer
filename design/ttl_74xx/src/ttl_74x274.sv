// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x274 - 4-bit x 4-bit binary multiplier. y = a * b (8-bit product).
module ttl_74x274 (
    input  logic [3:0] a, b,
    output logic [7:0] y
);
    assign y = 8'(a * b);
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x34 - Hex non-inverting buffer.
// y = a
module ttl_74x34 (
    input  logic [5:0] a,
    output logic [5:0] y
);
    assign y = a;
endmodule

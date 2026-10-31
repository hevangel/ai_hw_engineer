// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x152 - 8-to-1 multiplexer with inverting output. No enable input.
module ttl_74x152 (
    input  logic [2:0] s,
    input  logic [7:0] d,
    output logic       y_n
);
    assign y_n = ~d[s];
endmodule

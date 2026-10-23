// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x250 - 16-to-1 multiplexer (inverting output), no enable.
module ttl_74x250 (
    input  logic [3:0]  s,
    input  logic [15:0] d,
    output logic        y_n
);
    assign y_n = ~d[s];
endmodule

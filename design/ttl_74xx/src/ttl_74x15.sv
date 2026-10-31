// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x15 - Triple 3-input AND, open-collector
// Function: y[i] = a[i] & b[i] & c[i]
// OC physics not modeled.
// =============================================================================

module ttl_74x15 (
    input  logic [2:0] a,
    input  logic [2:0] b,
    input  logic [2:0] c,
    output logic [2:0] y
);

    assign y = a & b & c;

endmodule

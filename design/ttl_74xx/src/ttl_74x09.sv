// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x09 - Quad 2-input AND, open-collector outputs
//
// Function: y[i] = a[i] & b[i]
// Datasheet: SN74LS09 (https://www.ti.com/lit/gpn/sn74ls09)
// OC physics not modeled.
// =============================================================================

module ttl_74x09 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] y
);

    assign y = a & b;

endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x05 - Hex inverter, open-collector outputs
//
// Function: y[i] = ~a[i]
// Datasheet: SN74LS05 (https://www.ti.com/lit/gpn/sn74ls05)
// OC physics not modeled.
// =============================================================================

module ttl_74x05 (
    input  logic [5:0] a,
    output logic [5:0] y
);

    assign y = ~a;

endmodule

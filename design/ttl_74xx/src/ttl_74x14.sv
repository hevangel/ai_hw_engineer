// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x14 - Hex inverter, Schmitt-trigger inputs
// Function: y = ~a
// Datasheet: SN74LS14 (https://www.ti.com/lit/gpn/sn74ls14)
// Schmitt hysteresis not modeled.
// =============================================================================

module ttl_74x14 (
    input  logic [5:0] a,
    output logic [5:0] y
);

    assign y = ~a;

endmodule

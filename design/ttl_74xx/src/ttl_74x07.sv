// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x07 - Hex buffer/driver, open-collector 30V/40mA, non-inverting
//
// Function: y[i] = a[i]
// Datasheet: SN74LS07 (https://www.ti.com/lit/gpn/sn7407)
// Unsupported: OC + 30V/40mA drive. RTL is a wire.
// =============================================================================

module ttl_74x07 (
    input  logic [5:0] a,
    output logic [5:0] y
);

    assign y = a;

endmodule

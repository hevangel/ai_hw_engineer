// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x16 - Hex inverter buffer/driver, OC 15V/40mA
// Function: y = ~a
// Datasheet: SN7416 (https://www.ti.com/lit/gpn/sn7416)
// Unsupported: OC + 15V/40mA drive.
// =============================================================================

module ttl_74x16 (
    input  logic [5:0] a,
    output logic [5:0] y
);

    assign y = ~a;

endmodule

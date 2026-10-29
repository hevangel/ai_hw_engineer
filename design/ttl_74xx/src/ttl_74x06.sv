// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x06 - Hex inverter buffer/driver, open-collector 30V/40mA
//
// Function: y[i] = ~a[i]
// Datasheet: SN74LS06 (https://www.ti.com/lit/gpn/sn74ls06)
//
// Unsupported: OC output, high-voltage (30 V) / high-current (40 mA) drive.
// The RTL is the logical inversion only. See spec/spec.md.
// =============================================================================

module ttl_74x06 (
    input  logic [5:0] a,
    output logic [5:0] y
);

    assign y = ~a;

endmodule

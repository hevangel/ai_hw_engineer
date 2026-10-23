// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x03 - Quad 2-input NAND, open-collector outputs
//
// Function: y[i] = ~(a[i] & b[i])
// Datasheet: SN74LS03 (https://www.ti.com/lit/gpn/sn54ls03)
//
// Open-collector physics not modeled. See spec/spec.md.
// Pinout differs from 74x01 but logic is identical.
// =============================================================================

module ttl_74x03 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] y
);

    assign y = ~(a & b);

endmodule

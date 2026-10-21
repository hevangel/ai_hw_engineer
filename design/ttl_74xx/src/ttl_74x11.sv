// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x11 - Triple 3-input AND gate
// Function: y[i] = a[i] & b[i] & c[i]
// Datasheet: SN74LS11 (https://www.ti.com/lit/gpn/sn74ls11)
// =============================================================================

module ttl_74x11 (
    input  logic [2:0] a,
    input  logic [2:0] b,
    input  logic [2:0] c,
    output logic [2:0] y
);

    assign y = a & b & c;

endmodule

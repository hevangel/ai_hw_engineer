// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x10 - Triple 3-input NAND gate
// Function: y[i] = ~(a[i] & b[i] & c[i])  for i in 0..2
// Datasheet: SN74LS10 (https://www.ti.com/lit/gpn/sn74ls10)
// =============================================================================

module ttl_74x10 (
    input  logic [2:0] a,
    input  logic [2:0] b,
    input  logic [2:0] c,
    output logic [2:0] y
);

    assign y = ~(a & b & c);

endmodule

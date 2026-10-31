// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x20 - Dual 4-input NAND gate
// Function: y[i] = ~(a[i] & b[i] & c[i] & d[i])  for i in 0..1
// Datasheet: SN74LS20 (https://www.ti.com/lit/gpn/sn74ls20)
// =============================================================================

module ttl_74x20 (
    input  logic [1:0] a,
    input  logic [1:0] b,
    input  logic [1:0] c,
    input  logic [1:0] d,
    output logic [1:0] y
);

    assign y = ~(a & b & c & d);

endmodule

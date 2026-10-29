// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x13 - Dual 4-input NAND, Schmitt-trigger inputs
//
// Function: y[i] = ~(a[i] & b[i] & c[i] & d[i])  for i in 0..1
// Datasheet: SN74LS13 (https://archive.org/details/bitsavers_tidataBookVol2_45945352/page/n125)
//
// Schmitt-trigger input hysteresis is an analog property and is not modeled;
// the inputs are treated as plain logic. See
// spec/spec.md.
// =============================================================================

module ttl_74x13 (
    input  logic [1:0] a,
    input  logic [1:0] b,
    input  logic [1:0] c,
    input  logic [1:0] d,
    output logic [1:0] y
);

    assign y = ~(a & b & c & d);

endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x01 - Quad 2-input NAND, open-collector outputs
//
// Function: y[i] = ~(a[i] & b[i])   for i in 0..3
// Datasheet: SN74LS01 (https://archive.org/details/bitsavers_tidataBookVol2_45945352/page/n61/)
//
// Unsupported physical behavior
// -----------------------------
// Open-collector output stage. Multiple OC outputs share an external pull-up
// to form wired-AND. This RTL drives outputs normally; wired-AND must be
// done at the next level of hierarchy. See spec/spec.md.
// =============================================================================

module ttl_74x01 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] y
);

    assign y = ~(a & b);

endmodule

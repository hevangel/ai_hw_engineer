// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x241 - Octal buffer / line driver, non-inverting outputs, 3-state.
// One bank active-low OE, other active-high OE.
module ttl_74x241 (
    input  logic [7:0] a,
    input  logic       oe1_n,
    input  logic       oe2,
    output logic [7:0] y,
    output logic [7:0] drive_en
);
    assign y[3:0] = oe1_n ? 4'h0 : a[3:0];
    assign y[7:4] = oe2   ? a[7:4] : 4'h0;
    assign drive_en = {{4{oe2}}, {4{~oe1_n}}};
endmodule

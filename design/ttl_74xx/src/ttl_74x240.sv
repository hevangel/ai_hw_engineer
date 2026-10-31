// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x240 - Octal buffer / line driver, inverting outputs, 3-state.
module ttl_74x240 (
    input  logic [7:0] a,
    input  logic       oe1_n, oe2_n,
    output logic [7:0] y,
    output logic [7:0] drive_en
);
    assign y[3:0] = oe1_n ? 4'h0 : ~a[3:0];
    assign y[7:4] = oe2_n ? 4'h0 : ~a[7:4];
    assign drive_en = {{4{~oe2_n}}, {4{~oe1_n}}};
endmodule

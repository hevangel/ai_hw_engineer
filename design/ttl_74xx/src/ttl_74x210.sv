// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x210 - Octal inverting buffer with 3-state outputs.
module ttl_74x210 (
    input  logic [7:0] a,
    input  logic       oe_n,
    output logic [7:0] y,
    output logic [7:0] drive_en
);
    assign y = oe_n ? 8'h00 : ~a;
    assign drive_en = '1 & {8{~oe_n}};
endmodule

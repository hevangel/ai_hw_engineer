// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x134 - Single 12-input NAND gate with 3-state output.
// y = (oe_n) ? 0 : ~(&a)
module ttl_74x134 (
    input  logic [11:0] a,
    input  logic        oe_n,
    output logic        y,
    output logic  drive_en
);
    assign y = oe_n ? 1'b0 : ~(&a);
    assign drive_en = ~oe_n;
endmodule

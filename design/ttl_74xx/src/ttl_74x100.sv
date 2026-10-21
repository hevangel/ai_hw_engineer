// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x100 - Dual 4-bit bistable latch (8 D latches in two groups of 4).
// le[0] gates bits 0-3, le[1] gates bits 4-7. Transparent on LE=1.
module ttl_74x100 (
    input  logic [1:0] le,
    input  logic [7:0] d,
    output logic [7:0] q
);
    logic [7:0] latch_q;
    always_latch begin
        if (le[0]) latch_q[3:0] = d[3:0];
        if (le[1]) latch_q[7:4] = d[7:4];
    end
    assign q = latch_q;
endmodule

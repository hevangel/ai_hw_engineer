// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x118 - Hex set/reset latch, shared reset.
// Six S-R latches with shared async reset (clr_n active low).
// Set inputs s[5:0] active high. When s=1, latch sets to 1. Otherwise hold.
module ttl_74x118 (
    input  logic       clr_n,
    input  logic [5:0] s,
    output logic [5:0] q
);
    logic [5:0] latch_q;
    always_latch begin
        if (!clr_n) latch_q = 6'b000000;
        else for (int i = 0; i < 6; i++) if (s[i]) latch_q[i] = 1'b1;
    end
    assign q = latch_q;
endmodule

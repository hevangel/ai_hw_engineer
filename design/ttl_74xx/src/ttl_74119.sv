// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74119 - Hex set/reset latch (per-bit clear).
// Six S-R latches with per-bit clear_n.
module ttl_74119 (
    input  logic [5:0] clr_n,
    input  logic [5:0] s,
    output logic [5:0] q
);
    logic [5:0] latch_q;
    always_latch begin
        if (!clr_n[0])      latch_q[0] = 1'b0; else if (s[0]) latch_q[0] = 1'b1;
        if (!clr_n[1])      latch_q[1] = 1'b0; else if (s[1]) latch_q[1] = 1'b1;
        if (!clr_n[2])      latch_q[2] = 1'b0; else if (s[2]) latch_q[2] = 1'b1;
        if (!clr_n[3])      latch_q[3] = 1'b0; else if (s[3]) latch_q[3] = 1'b1;
        if (!clr_n[4])      latch_q[4] = 1'b0; else if (s[4]) latch_q[4] = 1'b1;
        if (!clr_n[5])      latch_q[5] = 1'b0; else if (s[5]) latch_q[5] = 1'b1;
    end
    assign q = latch_q;
endmodule

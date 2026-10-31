// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x75 - 4-bit bistable latch, complementary outputs.
// Four D latches in two groups of two. Each group shares one LE.
// LE=1: transparent; LE=0: hold.
module ttl_74x75 (
    input  logic [1:0] le,   // le[0] gates bits 0-1, le[1] gates bits 2-3
    input  logic [3:0] d,
    output logic [3:0] q,
    output logic [3:0] q_n
);
    logic [3:0] latch_q;

    always_latch begin
        if (le[0]) begin
            latch_q[0] = d[0];
            latch_q[1] = d[1];
        end
        if (le[1]) begin
            latch_q[2] = d[2];
            latch_q[3] = d[3];
        end
    end

    assign q   = latch_q;
    assign q_n = ~latch_q;
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x77 - 4-bit bistable latch (no Q-bar).
// Same as 74x75 minus the complement outputs.
module ttl_74x77 (
    input  logic [1:0] le,
    input  logic [3:0] d,
    output logic [3:0] q
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

    assign q = latch_q;
endmodule

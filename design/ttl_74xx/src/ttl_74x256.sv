// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x256 - Dual 4-bit addressable latch.
// Two 4-bit latches; each bit individually addressable via a[1:0] and gated
// by enable g_n. Async clear.
module ttl_74x256 (
    input  logic       g_n,
    input  logic       clr_n,
    input  logic [1:0] a,
    input  logic [1:0] d,
    output logic [7:0] q
);
    for (genvar i = 0; i < 8; i++) begin : g_latch
        logic state;
        assign q[i] = state;
        always_latch begin
            if (!g_n && a == 2'(i % 4)) state = d[i/4];
            else if (!clr_n) state = 1'b0;
        end
    end
endmodule

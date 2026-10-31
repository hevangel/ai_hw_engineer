// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x259 - 8-bit bit-addressable input latch with clear.
module ttl_74x259 (
    input  logic       g_n,
    input  logic       clr_n,
    input  logic [2:0] a,
    input  logic       d,
    output logic [7:0] q
);
    for (genvar i = 0; i < 8; i++) begin : g_latch
        logic state;
        assign q[i] = state;
        always_latch begin
            if (!g_n && a == 3'(i)) state = d;
            else if (!clr_n) state = 1'b0;
        end
    end
endmodule

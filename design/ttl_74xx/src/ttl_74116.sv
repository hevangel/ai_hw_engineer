// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74116 - Dual 4-bit latch with clear.
// Each 4-bit group has le and clr_n. Async clear, transparent latch when le=1.
module ttl_74116 (
    input  logic [1:0] le,
    input  logic [1:0] clr_n,
    input  logic [7:0] d,
    output logic [7:0] q
);
    logic [7:0] latch_q;

    // Group 0 (bits 3:0): async clear + transparent latch
    always_latch begin
        if (!clr_n[0])      latch_q[3:0] = 4'h0;
        else if (le[0])     latch_q[3:0] = d[3:0];
    end
    // Group 1 (bits 7:4)
    always_latch begin
        if (!clr_n[1])      latch_q[7:4] = 4'h0;
        else if (le[1])     latch_q[7:4] = d[7:4];
    end

    assign q = latch_q;
endmodule

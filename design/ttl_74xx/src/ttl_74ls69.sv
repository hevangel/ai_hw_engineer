// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74ls69 - Dual 4-bit binary counters.
// Two independent 4-bit binary counters; each counts 0..15 then wraps.
module ttl_74ls69 (
    input  logic [1:0] clk,
    input  logic [1:0] clr_n,
    output logic [3:0] q0,
    output logic [3:0] q1
);
    always_ff @(posedge clk[0] or negedge clr_n[0]) begin
        if (!clr_n[0]) q0 <= 4'd0;
        else q0 <= q0 + 4'd1;
    end
    always_ff @(posedge clk[1] or negedge clr_n[1]) begin
        if (!clr_n[1]) q1 <= 4'd0;
        else q1 <= q1 + 4'd1;
    end
endmodule

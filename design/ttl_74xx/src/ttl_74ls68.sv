// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74ls68 - Dual 4-bit decade (BCD) counters.
// Two independent BCD counters; each counts 0..9 then wraps to 0.
// Each has its own clock and async clear.
module ttl_74ls68 (
    input  logic [1:0] clk,
    input  logic [1:0] clr_n,
    output logic [3:0] q0,
    output logic [3:0] q1
);
    always_ff @(posedge clk[0] or negedge clr_n[0]) begin
        if (!clr_n[0]) q0 <= 4'd0;
        else if (q0 == 4'd9) q0 <= 4'd0;
        else q0 <= q0 + 4'd1;
    end
    always_ff @(posedge clk[1] or negedge clr_n[1]) begin
        if (!clr_n[1]) q1 <= 4'd0;
        else if (q1 == 4'd9) q1 <= 4'd0;
        else q1 <= q1 + 4'd1;
    end
endmodule

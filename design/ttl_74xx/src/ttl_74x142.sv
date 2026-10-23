// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x142 - Decade counter / latch / decoder / driver for Nixie tubes.
// Integrates: BCD decade counter + transparent latch + BCD-to-decimal decoder.
//
// clk: counter clock (posedge)
// clr_n: async clear (counter)
// le: latch enable (1 = transparent)
// y_n[9:0]: active-low decoded outputs (OC HV in original; not modeled)
//
// Carry output: c_n goes low when counter wraps from 9 to 0.
module ttl_74x142 (
    input  logic clk,
    input  logic clr_n,
    input  logic le,
    output logic [9:0] y_n,
    output logic c_n
);
    logic [3:0] cnt;
    logic [3:0] latch_q;

    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n)        cnt <= 4'd0;
        else if (cnt == 4'd9) cnt <= 4'd0;
        else               cnt <= cnt + 4'd1;
    end

    always_latch begin
        if (le) latch_q = cnt;
    end

    always_comb begin
        y_n = 10'b1111111111;
        if (latch_q < 4'd10) y_n[latch_q] = 1'b0;
    end

    assign c_n = ~(cnt == 4'd9);
endmodule

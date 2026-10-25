// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x164 - 8-bit serial-in / parallel-out (SIPO) shift register, async clear.
// On posedge clk: q <= {q[6:0], a & b}.
module ttl_74x164 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic       a, b,
    output logic [7:0] q
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) q <= 8'h00;
        else        q <= {q[6:0], a & b};
    end
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x175 - Quad D FF, shared clock and async clear, with Q and Q_n.
module ttl_74x175 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic [3:0] d,
    output logic [3:0] q,
    output logic [3:0] q_n
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) q <= 4'h0;
        else        q <= d;
    end
    assign q_n = ~q;
endmodule

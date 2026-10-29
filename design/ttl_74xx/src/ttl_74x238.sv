// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x238 - 3-to-8 line decoder/demultiplexer, active-high outputs.
module ttl_74x238 (
    input  logic [2:0] a,
    input  logic       g1,
    input  logic       g2a_n,
    input  logic       g2b_n,
    output logic [7:0] y
);
    logic enable;
    assign enable = g1 & ~g2a_n & ~g2b_n;
    always_comb begin
        y = 8'h00;
        if (enable) y[a] = 1'b1;
    end
endmodule

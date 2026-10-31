// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x298 - Quad 2-input mux with storage. On posedge clk: q <= select ? b : a.
module ttl_74x298 (
    input  logic       clk,
    input  logic       select,
    input  logic [3:0] a, b,
    output logic [3:0] q
);
    always_ff @(posedge clk) begin
        q <= select ? b : a;
    end
endmodule

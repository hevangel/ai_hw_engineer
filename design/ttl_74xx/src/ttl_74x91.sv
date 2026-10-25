// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x91 - 8-bit shift register, serial in (gated AND), serial out.
// Each posedge clk: q[7:0] <= {q[6:0], a & b}
module ttl_74x91 (
    input  logic clk,
    input  logic a,
    input  logic b,
    output logic q_h,    // last bit (MSB end)
    output logic q_h_n
);
    logic [7:0] sr;
    always_ff @(posedge clk) begin
        sr <= {sr[6:0], a & b};
    end
    assign q_h   =  sr[7];
    assign q_h_n = ~sr[7];
endmodule

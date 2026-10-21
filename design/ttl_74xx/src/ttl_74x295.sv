// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x295 - 4-bit bidirectional shift register, 3-state outputs.
// mode controls shift direction; s_l selects parallel load.
module ttl_74x295 (
    input  logic       clk,
    input  logic       oe_n,
    input  logic       s_l,        // 1=parallel load
    input  logic       dir,        // 0=right, 1=left
    input  logic       din,
    input  logic [3:0] p,
    output logic [3:0] q,
    output logic [3:0] drive_en
);
    logic [3:0] sr;
    always_ff @(posedge clk) begin
        if (s_l)       sr <= p;
        else if (dir)  sr <= {sr[2:0], din};
        else           sr <= {din, sr[3:1]};
    end
    assign q = oe_n ? 4'h0 : sr;
    assign drive_en = '1 & {4{~oe_n}};
endmodule

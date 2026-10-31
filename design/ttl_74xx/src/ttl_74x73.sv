// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x73 - Dual JK flip-flop, async clear.
// Master-slave on original part; posedge-clocked here for FPGA synthesis.
module ttl_74x73 (
    input  logic [1:0] clk,
    input  logic [1:0] j,
    input  logic [1:0] k,
    input  logic [1:0] clr_n,
    output logic [1:0] q,
    output logic [1:0] q_n
);
    logic q_0, q_1;
    assign q = {q_1, q_0};
    always_ff @(posedge clk[0] or negedge clr_n[0]) begin
        if (!clr_n[0]) q_0 <= 1'b0;
        else case ({j[0], k[0]})
            2'b01: q_0 <= 1'b0;
            2'b10: q_0 <= 1'b1;
            2'b11: q_0 <= ~q_0;
            default: ;
        endcase
    end
    always_ff @(posedge clk[1] or negedge clr_n[1]) begin
        if (!clr_n[1]) q_1 <= 1'b0;
        else case ({j[1], k[1]})
            2'b01: q_1 <= 1'b0;
            2'b10: q_1 <= 1'b1;
            2'b11: q_1 <= ~q_1;
            default: ;
        endcase
    end
    assign q_n = ~q;
endmodule

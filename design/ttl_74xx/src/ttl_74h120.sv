// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74h120 - Dual JK FF, separate clock inputs (similar to 74x73).
module ttl_74h120 (
    input  logic [1:0] clk,
    input  logic [1:0] j,
    input  logic [1:0] k,
    output logic [1:0] q,
    output logic [1:0] q_n
);
    logic q_0, q_1;
    assign q = {q_1, q_0};
    always_ff @(posedge clk[0]) begin
        case ({j[0], k[0]})
            2'b01: q_0 <= 1'b0;
            2'b10: q_0 <= 1'b1;
            2'b11: q_0 <= ~q_0;
            default: ;
        endcase
    end
    always_ff @(posedge clk[1]) begin
        case ({j[1], k[1]})
            2'b01: q_1 <= 1'b0;
            2'b10: q_1 <= 1'b1;
            2'b11: q_1 <= ~q_1;
            default: ;
        endcase
    end
    assign q_n = ~q;
endmodule

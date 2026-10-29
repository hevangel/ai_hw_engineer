// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74h119 - Dual JK FF, shared clock and clear.
module ttl_74h119 (
    input  logic clk,
    input  logic clr_n,
    input  logic [1:0] j,
    input  logic [1:0] k,
    output logic [1:0] q,
    output logic [1:0] q_n
);
    logic q_0, q_1;
    assign q = {q_1, q_0};
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) {q_1,q_0} <= 2'b00;
        else begin
            case ({j[0], k[0]})
                2'b01: q_0 <= 1'b0;
                2'b10: q_0 <= 1'b1;
                2'b11: q_0 <= ~q_0;
                default: ;
            endcase
            case ({j[1], k[1]})
                2'b01: q_1 <= 1'b0;
                2'b10: q_1 <= 1'b1;
                2'b11: q_1 <= ~q_1;
                default: ;
            endcase
        end
    end
    assign q_n = ~q;
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x104 - JK master-slave flip-flop (single, no preset, no clear).
// Implemented as posedge for FPGA synthesis.
module ttl_74x104 (
    input  logic clk,
    input  logic j,
    input  logic k,
    output logic q,
    output logic q_n
);
    logic q_reg;
    always_ff @(posedge clk) begin
        case ({j, k})
            2'b01: q_reg <= 1'b0;
            2'b10: q_reg <= 1'b1;
            2'b11: q_reg <= ~q_reg;
            default: ;
        endcase
    end
    assign q   = q_reg;
    assign q_n = ~q_reg;
endmodule

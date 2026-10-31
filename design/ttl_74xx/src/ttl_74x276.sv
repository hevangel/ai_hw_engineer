// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x276 - Quad J-NotK edge-triggered FFs, separate clocks, shared preset/clear.
module ttl_74x276 (
    input  logic [3:0] clk,
    input  logic       clr_n,
    input  logic       pre_n,
    input  logic [3:0] j,
    input  logic [3:0] k_n,
    output logic [3:0] q
);
    generate
        for (genvar i = 0; i < 4; i++) begin : ff
            logic state;
            assign q[i] = state;
            always_ff @(posedge clk[i] or negedge clr_n or negedge pre_n) begin
                if (!clr_n)      state <= 1'b0;
                else if (!pre_n) state <= 1'b1;
                else case ({j[i], ~k_n[i]})
                    2'b01: state <= 1'b0;
                    2'b10: state <= 1'b1;
                    2'b11: state <= ~state;
                    default: ;
                endcase
            end
        end
    endgenerate
endmodule

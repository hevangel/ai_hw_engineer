// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x177 - Presettable binary counter/latch (÷2 + ÷8).
module ttl_74x177 (
    input  logic       clk_a,
    input  logic       clk_b,
    input  logic       clr_n,
    input  logic       load_n,
    input  logic [3:0] d,
    output logic       q_a,
    output logic       q_b,
    output logic       q_c,
    output logic       q_d
);
    logic [2:0] cnt8;

    always_ff @(posedge clk_a or negedge clr_n or negedge load_n) begin
        if (!clr_n)        q_a <= 1'b0;
        else if (!load_n)  q_a <= d[0];
        else               q_a <= ~q_a;
    end

    always_ff @(posedge clk_b or negedge clr_n or negedge load_n) begin
        if (!clr_n)        cnt8 <= 3'b000;
        else if (!load_n)  cnt8 <= d[3:1];
        else               cnt8 <= cnt8 + 3'b001;
    end

    assign q_b = cnt8[0];
    assign q_c = cnt8[1];
    assign q_d = cnt8[2];
endmodule

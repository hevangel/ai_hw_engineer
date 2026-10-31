// ASSUMPTION: Native edge inputs remain stable until sampled by sys_clk; integration must resolve separate edges as separate samples.
// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x193 - 4-bit up/down binary counter with separate count edges.
// Same FPGA deviation as 74x192: uses a system clock plus edge-detected
// clk_up / clk_dn enables to avoid Yosys multi-edge async issues.
module ttl_74x193 (
    input  logic       sys_clk,
    input  logic       clk_up,
    input  logic       clk_dn,
    input  logic       clr,
    input  logic       load_n,
    input  logic [3:0] d,
    output logic [3:0] q,
    output logic       co_n,
    output logic       bo_n
);
    logic clk_up_prev, clk_dn_prev;
    logic up_edge, dn_edge;
    assign up_edge = clk_up & ~clk_up_prev;
    assign dn_edge = clk_dn & ~clk_dn_prev;

    always_ff @(posedge sys_clk or posedge clr or negedge load_n) begin
        if (clr) begin
            q <= 4'd0;
            clk_up_prev <= 1'b0;
            clk_dn_prev <= 1'b0;
        end else if (!load_n) begin
            q <= d;
            clk_up_prev <= clk_up;
            clk_dn_prev <= clk_dn;
        end else begin
            clk_up_prev <= clk_up;
            clk_dn_prev <= clk_dn;
            if (up_edge)      q <= q + 4'd1;
            else if (dn_edge) q <= q - 4'd1;
        end
    end

    assign co_n = ~(q == 4'hF && clk_up);
    assign bo_n = ~(q == 4'h0 && clk_dn);
endmodule

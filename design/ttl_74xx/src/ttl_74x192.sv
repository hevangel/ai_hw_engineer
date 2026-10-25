// ASSUMPTION: Native edge inputs remain stable until sampled by sys_clk; integration must resolve separate edges as separate samples.
// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x192 - Synchronous 4-bit up/down BCD counter with separate count edges.
//
// FPGA-synthesis deviation: the original chip uses two clock pins clk_up and
// clk_dn; their rising edges advance the counter in the respective direction.
// Multiple clock-edge sensitivities don't synthesize cleanly with Yosys, so
// we add a single system clock and treat clk_up / clk_dn as edge-detected
// enable signals. The behavior is equivalent for any synchronous design
// where the original clocks are slower than the system clock.
// =============================================================================

module ttl_74x192 (
    input  logic       sys_clk,
    input  logic       clk_up,
    input  logic       clk_dn,
    input  logic       clr,         // active high
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
            if (up_edge) begin
                if (q == 4'd9) q <= 4'd0;
                else           q <= q + 4'd1;
            end else if (dn_edge) begin
                if (q == 4'd0) q <= 4'd9;
                else           q <= q - 4'd1;
            end
        end
    end

    assign co_n = ~(q == 4'd9 && clk_up);
    assign bo_n = ~(q == 4'd0 && clk_dn);
endmodule

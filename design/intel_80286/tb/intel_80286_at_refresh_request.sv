// IBM 5170 type 1 schematic, sheet 21: U68 and U95 request/clear path.
// The surrounding board must generate -REFRESH from actual bus arbitration.
module intel_80286_at_refresh_request (
    input  logic       reset_n_i,
    input  logic       timer_out1_i,
    input  logic       dma_clk_n_i,
    input  logic       sys_clk_i,
    input  logic       refresh_n_i,
    input  logic       io_ready_i,
    output logic       timer_latched_o,
    output logic       refresh_request_o,
    output logic [3:0] clear_chain_o
);
    logic q1, q2, q3, q4;
    assign clear_chain_o = {q4, q3, q2, q1};

    // U68's first D and both presets are tied high. Both active-low
    // clears are driven by U95 Q4, not directly by system reset.
    always_ff @(posedge timer_out1_i or negedge q4) begin
        if (!q4) timer_latched_o <= 1'b0;
        else timer_latched_o <= 1'b1;
    end
    always_ff @(posedge dma_clk_n_i or negedge q4) begin
        if (!q4) refresh_request_o <= 1'b0;
        else refresh_request_o <= timer_latched_o;
    end

    // U99 NOR and U92 AND feed U95 D1 and D3. Q1 feeds D2;
    // inverted Q3 feeds D4. CLR# is system -RESET.
    always_ff @(posedge sys_clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            q1 <= 1'b0; q2 <= 1'b0; q3 <= 1'b0; q4 <= 1'b0;
        end
        else begin
            q1 <= !(refresh_n_i || q3);
            q2 <= q1;
            q3 <= q2 && io_ready_i;
            q4 <= !q3;
        end
    end
endmodule

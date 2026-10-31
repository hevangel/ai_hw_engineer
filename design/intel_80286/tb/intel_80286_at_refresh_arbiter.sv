// IBM 5170 type 1 schematic sheet 21: U69/U121, U90, U98/U116/U81
// and U70. The U120/U92 CPU-HRQ inhibit is supplied by the caller.
// No reset is shown on these board latches; settle idle inputs before use.
module intel_80286_at_refresh_arbiter (
    input  logic sys_clk_i,
    input  logic refresh_request_i,
    input  logic dma_request_i,
    input  logic cpu_hlda_i,
    input  logic hold_permit_i,
    output logic cpu_hold_o,
    output logic refresh_o,
    output logic refresh_n_o,
    output logic dma_hlda_o,
    output logic refresh_selected_o,
    output logic dma_selected_o
);
    logic hold_latched;
    // U69 is an AND-OR-invert gate with U121 inverted feedback. With no
    // request its output is low; with HLDA low it tracks any request;
    // with HLDA high and a request present it holds its previous state.
    always_latch begin
        if (!refresh_request_i && !dma_request_i) hold_latched = 1'b0;
        else if (!cpu_hlda_i) hold_latched = 1'b1;
    end

    // U90 has cross-coupled active-low clears: each Q clears the other
    // flip-flop. The HDL models the digital relation, not metastability or
    // the physical resolution of simultaneous competing requests.
    /* verilator lint_off SYNCASYNCNET */
    always_ff @(posedge sys_clk_i or posedge dma_selected_o) begin
        if (dma_selected_o) refresh_selected_o <= 1'b0;
        else refresh_selected_o <= refresh_request_i;
    end
    always_ff @(posedge sys_clk_i or posedge refresh_selected_o) begin
        if (refresh_selected_o) dma_selected_o <= 1'b0;
        else dma_selected_o <= dma_request_i;
    end
    /* verilator lint_on SYNCASYNCNET */

    assign cpu_hold_o = hold_latched && hold_permit_i;
    assign refresh_o = cpu_hlda_i && hold_latched && refresh_selected_o;
    assign refresh_n_o = !refresh_o;
    assign dma_hlda_o = cpu_hlda_i && hold_latched && dma_selected_o;
endmodule

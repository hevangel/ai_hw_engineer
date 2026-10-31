// Partial IBM 5170 sheet-21 digital path. The caller supplies real timer
// OUT1, native CPU HLDA and the still-unmodeled U120/U92 hold permit.
module intel_80286_at_refresh_path (
    input  logic reset_n_i, sys_clk_i, dma_clk_n_i, timer_out1_i,
    input  logic dma_request_i, cpu_hlda_i, hold_permit_i, io_ready_i,
    output logic cpu_hold_o, refresh_o, refresh_n_o, dma_hlda_o, detect_o,
    output logic request_o, timer_latched_o,
    output logic refresh_selected_o, dma_selected_o,
    output logic [3:0] clear_chain_o,
    output logic [7:0] refresh_row_o,
    output logic refresh_row_oe_o, refresh_memr_n_o, refresh_memr_oe_o
);
    logic [7:0] unused_row_counter;
    intel_80286_at_refresh_request request (
        .reset_n_i(reset_n_i), .timer_out1_i(timer_out1_i),
        .dma_clk_n_i(dma_clk_n_i), .sys_clk_i(sys_clk_i),
        .refresh_n_i(refresh_n_o), .io_ready_i(io_ready_i),
        .timer_latched_o(timer_latched_o), .refresh_request_o(request_o),
        .clear_chain_o(clear_chain_o)
    );
    intel_80286_at_refresh_arbiter arbiter (
        .sys_clk_i(sys_clk_i), .refresh_request_i(request_o),
        .dma_request_i(dma_request_i), .cpu_hlda_i(cpu_hlda_i),
        .hold_permit_i(hold_permit_i), .cpu_hold_o(cpu_hold_o),
        .refresh_o(refresh_o), .refresh_n_o(refresh_n_o),
        .dma_hlda_o(dma_hlda_o), .refresh_selected_o(refresh_selected_o),
        .dma_selected_o(dma_selected_o)
    );
    intel_80286_at_refresh_detect detector (
        .refresh_i(refresh_o), .preset_n_i(1'b1), .detect_o(detect_o)
    );
    intel_80286_at_refresh_row row_counter (
        .reset_n_i(reset_n_i), .refresh_i(refresh_o),
        .chain_q1_i(clear_chain_o[0]), .chain_q2_i(clear_chain_o[1]),
        .row_o(refresh_row_o), .row_oe_o(refresh_row_oe_o),
        .memr_n_o(refresh_memr_n_o), .memr_oe_o(refresh_memr_oe_o),
        .counter_o(unused_row_counter)
    );
endmodule

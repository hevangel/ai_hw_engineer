// Native CPU connected to the partial IBM AT refresh request signal path.
// Timer OUT1, -DMA CLK, hold permit, IOCHRDY and external memory are supplied
// by the test; this is not a complete IBM AT motherboard.
module intel_80286_at_refresh_native (
    input logic clk_i, clk_2x_i, reset_i, ready_n_i,
    input logic timer_out1_i, dma_clk_n_i, hold_permit_i, io_ready_i,
    input logic [15:0] data_i,
    output logic [15:0] data_o,
    output logic data_oe_o, address_oe_o, status_oe_o, lock_n_o, lock_oe_o,
    output logic [23:0] address_o,
    output logic bhe_n_o, cod_inta_o, m_io_o, s1_o, s0_o,
    output logic hlda_o, cycle_active_o, protocol_error_o,
    output logic [1:0] completed_bytes_o,
    output logic halted_o, shutdown_o, fault_o,
    output logic hold_o, refresh_o, refresh_n_o, detect_o, request_o,
    output logic [3:0] clear_chain_o,
    output logic [7:0] refresh_row_o,
    output logic refresh_row_oe_o, refresh_memr_n_o, refresh_memr_oe_o
);
    logic cpu_reset, timer_latched, dma_hlda, refresh_selected, dma_selected;
    /* verilator lint_off PINMISSING */
    intel_80286_native_cpu cpu (
        .clk_i(clk_i), .clk_2x_i(clk_2x_i), .reset_i(reset_i), .res_n_i(1'b1),
        .ready_n_i(ready_n_i), .cenl_i(1'b1), .cen_i(1'b1), .cmdly_i(1'b0),
        .hold_i(hold_o), .intr_i(1'b0), .nmi_i(1'b0), .busy_i(1'b0),
        .error_n_i(1'b1), .data_i(data_i), .data_o(data_o),
        .data_oe_o(data_oe_o), .address_o(address_o), .address_oe_o(address_oe_o),
        .bhe_n_o(bhe_n_o), .cod_inta_o(cod_inta_o), .m_io_o(m_io_o),
        .s1_o(s1_o), .s0_o(s0_o), .status_oe_o(status_oe_o),
        .lock_n_o(lock_n_o), .lock_oe_o(lock_oe_o), .hlda_o(hlda_o),
        .cycle_active_o(cycle_active_o), .protocol_error_o(protocol_error_o),
        .completed_bytes_o(completed_bytes_o), .halted_o(halted_o),
        .shutdown_o(shutdown_o), .fault_o(fault_o), .cpu_reset_o(cpu_reset)
    );
    /* verilator lint_on PINMISSING */
    intel_80286_at_refresh_path refresh_path (
        .reset_n_i(!cpu_reset), .sys_clk_i(clk_2x_i), .dma_clk_n_i(dma_clk_n_i),
        .timer_out1_i(timer_out1_i), .dma_request_i(1'b0), .cpu_hlda_i(hlda_o),
        .hold_permit_i(hold_permit_i), .io_ready_i(io_ready_i), .cpu_hold_o(hold_o),
        .refresh_o(refresh_o), .refresh_n_o(refresh_n_o), .dma_hlda_o(dma_hlda),
        .detect_o(detect_o), .request_o(request_o), .timer_latched_o(timer_latched),
        .refresh_selected_o(refresh_selected), .dma_selected_o(dma_selected),
        .clear_chain_o(clear_chain_o), .refresh_row_o(refresh_row_o),
        .refresh_row_oe_o(refresh_row_oe_o), .refresh_memr_n_o(refresh_memr_n_o),
        .refresh_memr_oe_o(refresh_memr_oe_o)
    );
    // These outputs are intentionally left observable inside the fixture.
    logic unused_signals;
    assign unused_signals = timer_latched ^ dma_hlda ^ refresh_selected ^ dma_selected;
endmodule

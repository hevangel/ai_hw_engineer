// Native 286 + programmed 8254 + partial 5170 refresh signal path.
// External memory, clock phases, hold permit and IOCHRDY remain fixture inputs.
module intel_80286_at_refresh_timer_native (
    input logic clk_i, clk_2x_i, reset_i, ready_n_i,
    input logic dma_clk_n_i, hold_permit_i, io_ready_i,
    input logic pck_i, iochck_i,
    input logic [2:0] timer_clk_i,
    input logic [15:0] host_data_i,
    output logic [15:0] data_o,
    output logic data_oe_o, address_oe_o, status_oe_o, lock_n_o, lock_oe_o,
    output logic [23:0] address_o,
    output logic bhe_n_o, cod_inta_o, m_io_o, s1_o, s0_o,
    output logic hlda_o, cycle_active_o, protocol_error_o,
    output logic [1:0] completed_bytes_o,
    output logic halted_o, shutdown_o, fault_o,
    output logic hold_o, refresh_o, refresh_n_o, detect_o, request_o,
    output logic [3:0] clear_chain_o,
    output logic [2:0] timer_out_o,
    output logic timer_selected_o, timer_rdata_valid_o,
    output logic [7:0] refresh_row_o,
    output logic refresh_row_oe_o, refresh_memr_n_o, refresh_memr_oe_o,
    output logic port61_selected_o, port61_rdata_valid_o,
    output logic [7:0] port61_rdata_o,
    output logic [3:0] port61_control_o
);
    logic io_cycle;
    logic [7:0] timer_data;
    logic [15:0] cpu_data;
    logic [3:0] status;
    assign status={cod_inta_o,m_io_o,s1_o,s0_o};
    always_ff @(posedge clk_i) begin
        if (reset_i) io_cycle<=1'b0;
        else if (status_oe_o) io_cycle<=status==4'h9 || status==4'ha;
    end
    assign cpu_data = port61_rdata_valid_o ? {port61_rdata_o,8'h00} :
        timer_rdata_valid_o ? (address_o[0] ? {timer_data,8'h00} : {8'h00,timer_data}) : host_data_i;

    intel_80286_at_refresh_native native (
        .clk_i(clk_i), .clk_2x_i(clk_2x_i), .reset_i(reset_i), .ready_n_i(ready_n_i),
        .timer_out1_i(timer_out_o[1]), .dma_clk_n_i(dma_clk_n_i),
        .hold_permit_i(hold_permit_i), .io_ready_i(io_ready_i), .data_i(cpu_data),
        .data_o(data_o), .data_oe_o(data_oe_o), .address_oe_o(address_oe_o),
        .status_oe_o(status_oe_o), .lock_n_o(lock_n_o), .lock_oe_o(lock_oe_o),
        .address_o(address_o), .bhe_n_o(bhe_n_o), .cod_inta_o(cod_inta_o),
        .m_io_o(m_io_o), .s1_o(s1_o), .s0_o(s0_o), .hlda_o(hlda_o),
        .cycle_active_o(cycle_active_o), .protocol_error_o(protocol_error_o),
        .completed_bytes_o(completed_bytes_o), .halted_o(halted_o),
        .shutdown_o(shutdown_o), .fault_o(fault_o), .hold_o(hold_o),
        .refresh_o(refresh_o), .refresh_n_o(refresh_n_o), .detect_o(detect_o),
        .request_o(request_o), .clear_chain_o(clear_chain_o),
        .refresh_row_o(refresh_row_o), .refresh_row_oe_o(refresh_row_oe_o),
        .refresh_memr_n_o(refresh_memr_n_o), .refresh_memr_oe_o(refresh_memr_oe_o)
    );
    intel_80286_at_timer timer (
        .clk(clk_i), .rst_n(!reset_i),
        .io_req_i(address_oe_o && !status_oe_o && io_cycle),
        .io_ready_i(completed_bytes_o!=0), .io_write_i(data_oe_o),
        .io_addr_i(address_o[15:0]),
        .io_wdata_i(address_o[0] ? data_o[15:8] : data_o[7:0]),
        .port61_bit0_i(port61_control_o[0]), .counter_clk_i(timer_clk_i),
        .selected_o(timer_selected_o), .rdata_valid_o(timer_rdata_valid_o),
        .rdata_o(timer_data), .timer_out_o(timer_out_o)
    );
    intel_80286_at_port61 port61 (
        .clk(clk_i), .reset_n(!reset_i),
        .io_req_i(address_oe_o && !status_oe_o && io_cycle),
        .io_ready_i(completed_bytes_o!=0), .io_write_i(data_oe_o),
        .io_addr_i(address_o[15:0]), .io_wdata_i(data_o[11:8]),
        .refresh_detect_i(detect_o), .timer2_out_i(timer_out_o[2]),
        .iochck_i(iochck_i), .pck_i(pck_i), .selected_o(port61_selected_o),
        .rdata_valid_o(port61_rdata_valid_o), .rdata_o(port61_rdata_o),
        .control_o(port61_control_o)
    );
endmodule

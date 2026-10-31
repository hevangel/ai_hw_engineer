// Native-bus BIOS fixture. DMA is register-only; refresh rows are observed,
// not connected to DRAM. Clock timing and HOLD permit are fixture inputs.
module intel_80286_at_bios_native (
    input logic clk_i, clk_2x_i, reset_i, ready_n_i,
    input logic dma_clk_n_i, hold_permit_i, io_ready_i,
    input logic [2:0] timer_clk_i,
    input logic [15:0] host_data_i,
    output logic [15:0] data_o, cpu_data_o,
    output logic data_oe_o, address_oe_o, status_oe_o,
    output logic [23:0] address_o,
    output logic bhe_n_o, hlda_o, cycle_active_o, protocol_error_o,
    output logic [1:0] completed_bytes_o,
    output logic halted_o, shutdown_o, fault_o,
    output logic hold_o, refresh_o, detect_o, refresh_ras_trigger_o,
    output logic [7:0] refresh_row_o,
    output logic refresh_row_oe_o, refresh_memr_n_o, refresh_memr_oe_o,
    output logic io_cycle_o, fetch_cycle_o,
    output logic timer_selected_o, timer_rdata_valid_o,
    output logic port61_selected_o, port61_rdata_valid_o,
    output logic [7:0] port61_rdata_o,
    output logic dma_selected_o, dma_controller2_o, dma_rdata_valid_o,
    output logic [7:0] dma_rdata_o,
    output logic page_selected_o, page_rdata_valid_o,
    output logic [7:0] page_rdata_o,
    output logic [3:0] page_map_index_o,
    output logic [6:0] page_a23_a17_o,
    output logic page_a23_a17_oe_o, page_xa16_o, page_xa16_valid_o,
    output logic retire_o,
    output logic [23:0] retire_pc_o,
    output logic [7:0] retire_opcode_o,
    output logic [127:0] regs_o,
    output logic [63:0] segs_o,
    output logic [15:0] ip_o, flags_o
);
    logic cod_inta, m_io, s1, s0;
    logic [3:0] status;
    logic [7:0] map_data;
    logic refresh_n;
    logic [15:0] fixture_data;
    // ASSUMPTION: while HLDA grants refresh, the other masters release
    // -MEMR and -MEMW and the board pull-ups hold undriven lines high.
    // This monitor does not resolve normal CPU memory cycles.
    intel_80286_at_memory_ras ras_gate (
        .memr_n_i(refresh_memr_oe_o ? refresh_memr_n_o : 1'b1),
        .memw_n_i(1'b1), .ras_trigger_o(refresh_ras_trigger_o)
    );
    assign status={cod_inta,m_io,s1,s0};
    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            io_cycle_o<=1'b0;
            fetch_cycle_o<=1'b0;
        end else if (status_oe_o) begin
            io_cycle_o<=status==4'h9 || status==4'ha;
            fetch_cycle_o<=status==4'hd;
        end
    end
    assign fixture_data = dma_rdata_valid_o ?
        (address_o[0] ? {dma_rdata_o,8'h00} : {8'h00,dma_rdata_o}) :
        page_rdata_valid_o ?
        (address_o[0] ? {page_rdata_o,8'h00} : {8'h00,page_rdata_o}) : host_data_i;

    /* verilator lint_off PINMISSING */
    intel_80286_at_refresh_timer_native fixture (
        .clk_i(clk_i), .clk_2x_i(clk_2x_i), .reset_i(reset_i), .ready_n_i(ready_n_i),
        .dma_clk_n_i(dma_clk_n_i), .hold_permit_i(hold_permit_i), .io_ready_i(io_ready_i),
        .pck_i(1'b0), .iochck_i(1'b0), .timer_clk_i(timer_clk_i), .host_data_i(fixture_data),
        .data_o(data_o), .data_oe_o(data_oe_o), .address_oe_o(address_oe_o),
        .status_oe_o(status_oe_o), .address_o(address_o), .bhe_n_o(bhe_n_o),
        .cod_inta_o(cod_inta), .m_io_o(m_io), .s1_o(s1), .s0_o(s0),
        .hlda_o(hlda_o), .cycle_active_o(cycle_active_o), .protocol_error_o(protocol_error_o),
        .completed_bytes_o(completed_bytes_o), .halted_o(halted_o), .shutdown_o(shutdown_o),
        .fault_o(fault_o), .hold_o(hold_o), .refresh_o(refresh_o), .refresh_n_o(refresh_n), .detect_o(detect_o),
        .refresh_row_o(refresh_row_o), .refresh_row_oe_o(refresh_row_oe_o),
        .refresh_memr_n_o(refresh_memr_n_o), .refresh_memr_oe_o(refresh_memr_oe_o),
        .timer_selected_o(timer_selected_o), .timer_rdata_valid_o(timer_rdata_valid_o),
        .port61_selected_o(port61_selected_o), .port61_rdata_valid_o(port61_rdata_valid_o),
        .port61_rdata_o(port61_rdata_o)
    );
    /* verilator lint_on PINMISSING */
    intel_80286_at_dma dma (
        .clk(clk_i), .rst_n(!reset_i),
        .io_req_i(address_oe_o && !status_oe_o && io_cycle_o),
        .io_ready_i(completed_bytes_o!=0), .io_write_i(data_oe_o),
        .io_addr_i(address_o[15:0]),
        .io_wdata_i(address_o[0] ? data_o[15:8] : data_o[7:0]),
        .selected_o(dma_selected_o), .controller2_o(dma_controller2_o),
        .rdata_valid_o(dma_rdata_valid_o), .rdata_o(dma_rdata_o)
    );
    intel_80286_at_page page (
        .clk(clk_i), .rst_n(!reset_i),
        .io_req_i(address_oe_o && !status_oe_o && io_cycle_o),
        .io_ready_i(completed_bytes_o!=0), .io_write_i(data_oe_o),
        .io_addr_i(address_o[15:0]),
        .io_wdata_i(address_o[0] ? data_o[15:8] : data_o[7:0]),
        .map_index_i(page_map_index_o), .selected_o(page_selected_o),
        .rdata_valid_o(page_rdata_valid_o), .rdata_o(page_rdata_o), .map_data_o(map_data)
    );
    // ASSUMPTION: DREQ is tied low in this register-only DMA fixture. No external master
    // or controller-1 DMA cycle is modeled; these inactive levels are inputs
    // to the physical gate model, not evidence of full DMA arbitration.
    intel_80286_at_page_map page_map (
        .refresh_n_i(refresh_n), .dack0_n_i(1'b1), .dack2_n_i(1'b1), .dack3_n_i(1'b1),
        .dack4_n_i(1'b1), .dack6_n_i(1'b1), .dack7_n_i(1'b1),
        .hlda_i(hlda_o), .master_n_i(1'b1), .aen1_n_i(1'b1), .map_data_i(map_data),
        .map_index_o(page_map_index_o), .a23_a17_o(page_a23_a17_o),
        .a23_a17_oe_o(page_a23_a17_oe_o), .xa16_o(page_xa16_o), .xa16_valid_o(page_xa16_valid_o)
    );
    // Internal retirement taps are verification-only observability.
    assign retire_o=fixture.native.cpu.core.retire_o;
    assign retire_pc_o=fixture.native.cpu.core.retire_pc_o;
    assign retire_opcode_o=fixture.native.cpu.core.retire_opcode_o;
    assign regs_o=fixture.native.cpu.core.regs_o;
    assign segs_o=fixture.native.cpu.core.segs_o;
    assign ip_o=fixture.native.cpu.core.ip_o;
    assign flags_o=fixture.native.cpu.core.flags_o;
    assign cpu_data_o=fixture.cpu_data;
endmodule

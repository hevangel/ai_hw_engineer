// CPU plus timer and DMA-register verification fixture, not an IBM AT board.
module intel_80286_at_fixture (
    input  logic         clk, rst_n,
    input  logic         bus_ready_i,
    input  logic [15:0]  host_rdata_i,
    input  logic [2:0]   timer_clk_i,
    input  logic         timer_gate2_i,
    output logic         bus_req_o, bus_fetch_o, bus_write_o, bus_io_o,
    output logic [23:0]  bus_addr_o,
    output logic [15:0]  bus_wdata_o,
    output logic         timer_selected_o, timer_rdata_valid_o,
    output logic [7:0]   timer_rdata_o,
    output logic [2:0]   timer_out_o,
    output logic         dma_selected_o, dma_controller2_o, dma_rdata_valid_o,
    output logic [7:0]   dma_rdata_o,
    output logic         page_selected_o, page_rdata_valid_o,
    output logic [7:0]   page_rdata_o,
    output logic         halted_o, shutdown_o, fault_o, retire_o,
    output logic [23:0]  retire_pc_o,
    output logic [7:0]   retire_opcode_o,
    output logic [127:0] regs_o,
    output logic [63:0]  segs_o,
    output logic [15:0]  ip_o, flags_o
);
    logic [15:0] cpu_rdata;
    logic [7:0] unused_page_map_data;
    assign cpu_rdata = timer_rdata_valid_o ? {8'h00, timer_rdata_o} :
                       dma_rdata_valid_o ? {8'h00, dma_rdata_o} :
                       page_rdata_valid_o ? {8'h00, page_rdata_o} : host_rdata_i;

    // The unused observability outputs remain available in the core itself.
    /* verilator lint_off PINMISSING */
    intel_80286 cpu (
        .clk(clk), .rst_n(rst_n), .bus_ready_i(bus_ready_i),
        .bus_rdata_i(cpu_rdata), .intr_i(1'b0), .nmi_i(1'b0),
        .inta_ready_i(1'b0), .inta_vector_i(8'h00),
        .busy_i(1'b0), .error_n_i(1'b1),
        .bus_req_o(bus_req_o), .bus_fetch_o(bus_fetch_o),
        .bus_write_o(bus_write_o), .bus_io_o(bus_io_o),
        .bus_addr_o(bus_addr_o), .bus_wdata_o(bus_wdata_o),
        .halted_o(halted_o), .shutdown_o(shutdown_o), .fault_o(fault_o),
        .retire_o(retire_o), .retire_pc_o(retire_pc_o),
        .retire_opcode_o(retire_opcode_o), .regs_o(regs_o),
        .segs_o(segs_o), .ip_o(ip_o), .flags_o(flags_o)
    );
    /* verilator lint_on PINMISSING */

    intel_80286_at_timer timer (
        .clk(clk), .rst_n(rst_n), .io_req_i(bus_req_o && bus_io_o),
        .io_ready_i(bus_ready_i), .io_write_i(bus_write_o),
        .io_addr_i(bus_addr_o[15:0]), .io_wdata_i(bus_wdata_o[7:0]),
        .port61_bit0_i(timer_gate2_i), .counter_clk_i(timer_clk_i),
        .selected_o(timer_selected_o), .rdata_valid_o(timer_rdata_valid_o),
        .rdata_o(timer_rdata_o), .timer_out_o(timer_out_o)
    );
    intel_80286_at_dma dma_registers (
        .clk(clk), .rst_n(rst_n), .io_req_i(bus_req_o && bus_io_o),
        .io_ready_i(bus_ready_i), .io_write_i(bus_write_o),
        .io_addr_i(bus_addr_o[15:0]), .io_wdata_i(bus_wdata_o[7:0]),
        .selected_o(dma_selected_o), .controller2_o(dma_controller2_o),
        .rdata_valid_o(dma_rdata_valid_o), .rdata_o(dma_rdata_o)
    );
    intel_80286_at_page page_registers (
        .clk(clk), .rst_n(rst_n), .io_req_i(bus_req_o && bus_io_o),
        .io_ready_i(bus_ready_i), .io_write_i(bus_write_o),
        .io_addr_i(bus_addr_o[15:0]), .io_wdata_i(bus_wdata_o[7:0]),
        .map_index_i(4'h0), .selected_o(page_selected_o),
        .rdata_valid_o(page_rdata_valid_o), .rdata_o(page_rdata_o),
        .map_data_o(unused_page_map_data)
    );
endmodule

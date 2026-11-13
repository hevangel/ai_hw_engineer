// IBM PC AT 5170 type-1 system board, milestone M1 skeleton.
//
// Composes the native 80286, the 8254 timer, port 61h, the refresh request
// path, two 8237 register interfaces, the 74LS612 page registers and the
// refresh page-map gating. The device modules are the 286 design's
// schematic-cited AT models (design/intel_80286/tb/intel_80286_at_*.sv),
// reused in place so there is one implementation.
//
// Memory is external: the host supplies read data for the current memory
// cycle on mem_rdata_i and performs writes from data_o. I/O reads are served
// only by modeled devices. io_unclaimed_o flags an I/O cycle that no modeled
// device decodes, so a run stops at the first missing device instead of
// reading a guessed value.
//
// Not yet modeled: 8042 keyboard controller, MC146818 CMOS and NMI mask,
// both 8259 interrupt controllers (INTR is tied low), DMA requests and
// transfers, DRAM, video, diskette and fixed disk.
module ibm_pc_at_5170 (
    input  logic        clk_i, clk_2x_i, reset_i, ready_n_i,
    input  logic        dma_clk_n_i, hold_permit_i, refresh_ready_i,
    input  logic [2:0]  timer_clk_i,
    input  logic [15:0] mem_rdata_i,
    output logic [23:0] address_o,
    output logic [15:0] data_o,
    output logic        data_oe_o, address_oe_o, bhe_n_o,
    output logic        io_cycle_o, fetch_cycle_o,
    output logic [1:0]  completed_bytes_o,
    output logic        hlda_o, cycle_active_o, protocol_error_o,
    output logic        halted_o, shutdown_o, fault_o,
    output logic        refresh_o, refresh_ras_trigger_o,
    output logic [7:0]  refresh_row_o,
    output logic        refresh_row_oe_o, refresh_memr_n_o, refresh_memr_oe_o,
    output logic [3:0]  page_map_index_o,
    output logic [6:0]  page_a23_a17_o,
    output logic        page_a23_a17_oe_o, page_xa16_o, page_xa16_valid_o,
    output logic        io_claimed_o, io_unclaimed_o, io_read_undriven_o,
    output logic [7:0]  post_code_o
);
    logic cod_inta, m_io, s1, s0, status_oe, hold, detect, refresh_n;
    logic io_req, io_accept, io_write;
    logic [7:0] io_wdata, map_data;
    logic timer_sel, timer_valid, port61_sel, port61_valid;
    logic dma_sel, dma_ctrl2, dma_valid, page_sel, page_valid;
    logic [7:0] port61_rdata, dma_rdata, page_rdata;
    logic [15:0] board_data;

    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            io_cycle_o <= 1'b0;
            fetch_cycle_o <= 1'b0;
        end else if (status_oe) begin
            io_cycle_o <= {cod_inta, m_io, s1, s0} == 4'h9 || {cod_inta, m_io, s1, s0} == 4'ha;
            fetch_cycle_o <= {cod_inta, m_io, s1, s0} == 4'hd;
        end
    end

    assign io_req = address_oe_o && !status_oe && io_cycle_o;
    assign io_accept = completed_bytes_o != 2'd0;
    assign io_write = data_oe_o;
    assign io_wdata = address_o[0] ? data_o[15:8] : data_o[7:0];

    // DMA and page-register reads enter the CPU through the fixture's data
    // input; timer and port 61h reads are muxed inside it. Memory reads come
    // from the host. Nothing else drives the bus during an I/O cycle.
    assign board_data = dma_valid ? (address_o[0] ? {dma_rdata, 8'h00} : {8'h00, dma_rdata}) :
                        page_valid ? (address_o[0] ? {page_rdata, 8'h00} : {8'h00, page_rdata}) :
                        io_cycle_o ? 16'h0000 : mem_rdata_i;

    assign io_claimed_o = timer_sel || port61_sel || dma_sel || page_sel;
    assign io_unclaimed_o = io_req && !io_claimed_o;
    assign io_read_undriven_o = io_req && !io_write &&
        ((timer_sel && !timer_valid) || (port61_sel && !port61_valid) ||
         (dma_sel && !dma_valid) || (page_sel && !page_valid));

    // Port 80h is the 74LS612 slot the BIOS uses for its manufacturing
    // checkpoints (for example MOV AL,0Ah / OUT 80h at F000:03A2). The value
    // is kept here only as an observation of that register.
    always_ff @(posedge clk_i) begin
        if (reset_i) post_code_o <= 8'h00;
        else if (io_req && io_accept && io_write && address_o[15:0] == 16'h0080) post_code_o <= io_wdata;
    end

    /* verilator lint_off PINMISSING */
    intel_80286_at_refresh_timer_native core (
        .clk_i(clk_i), .clk_2x_i(clk_2x_i), .reset_i(reset_i), .ready_n_i(ready_n_i),
        .dma_clk_n_i(dma_clk_n_i), .hold_permit_i(hold_permit_i), .io_ready_i(refresh_ready_i),
        .pck_i(1'b0), .iochck_i(1'b0), .timer_clk_i(timer_clk_i), .host_data_i(board_data),
        .data_o(data_o), .data_oe_o(data_oe_o), .address_oe_o(address_oe_o),
        .status_oe_o(status_oe), .address_o(address_o), .bhe_n_o(bhe_n_o),
        .cod_inta_o(cod_inta), .m_io_o(m_io), .s1_o(s1), .s0_o(s0),
        .hlda_o(hlda_o), .cycle_active_o(cycle_active_o), .protocol_error_o(protocol_error_o),
        .completed_bytes_o(completed_bytes_o), .halted_o(halted_o), .shutdown_o(shutdown_o),
        .fault_o(fault_o), .hold_o(hold), .refresh_o(refresh_o), .refresh_n_o(refresh_n),
        .detect_o(detect), .refresh_row_o(refresh_row_o), .refresh_row_oe_o(refresh_row_oe_o),
        .refresh_memr_n_o(refresh_memr_n_o), .refresh_memr_oe_o(refresh_memr_oe_o),
        .timer_selected_o(timer_sel), .timer_rdata_valid_o(timer_valid),
        .port61_selected_o(port61_sel), .port61_rdata_valid_o(port61_valid),
        .port61_rdata_o(port61_rdata)
    );
    /* verilator lint_on PINMISSING */

    intel_80286_at_dma dma (
        .clk(clk_i), .rst_n(!reset_i), .io_req_i(io_req), .io_ready_i(io_accept),
        .io_write_i(io_write), .io_addr_i(address_o[15:0]), .io_wdata_i(io_wdata),
        .selected_o(dma_sel), .controller2_o(dma_ctrl2),
        .rdata_valid_o(dma_valid), .rdata_o(dma_rdata)
    );
    intel_80286_at_page page (
        .clk(clk_i), .rst_n(!reset_i), .io_req_i(io_req), .io_ready_i(io_accept),
        .io_write_i(io_write), .io_addr_i(address_o[15:0]), .io_wdata_i(io_wdata),
        .map_index_i(page_map_index_o), .selected_o(page_sel),
        .rdata_valid_o(page_valid), .rdata_o(page_rdata), .map_data_o(map_data)
    );
    // ASSUMPTION AT4: no DMA channel requests service in M1, so every DACK
    // is inactive and only refresh selects a page-map slot.
    intel_80286_at_page_map page_map (
        .refresh_n_i(refresh_n), .dack0_n_i(1'b1), .dack2_n_i(1'b1), .dack3_n_i(1'b1),
        .dack4_n_i(1'b1), .dack6_n_i(1'b1), .dack7_n_i(1'b1),
        .hlda_i(hlda_o), .master_n_i(1'b1), .aen1_n_i(1'b1), .map_data_i(map_data),
        .map_index_o(page_map_index_o), .a23_a17_o(page_a23_a17_o),
        .a23_a17_oe_o(page_a23_a17_oe_o), .xa16_o(page_xa16_o), .xa16_valid_o(page_xa16_valid_o)
    );
    // ASSUMPTION AT5: during a refresh grant the other masters release
    // -MEMR/-MEMW and pull-ups hold them high (inherited from the 286
    // native BIOS fixture). CPU memory cycles are not yet routed to RAS.
    intel_80286_at_memory_ras ras_gate (
        .memr_n_i(refresh_memr_oe_o ? refresh_memr_n_o : 1'b1),
        .memw_n_i(1'b1), .ras_trigger_o(refresh_ras_trigger_o)
    );

    logic unused;
    assign unused = ^{hold, detect, dma_ctrl2, port61_rdata};
endmodule

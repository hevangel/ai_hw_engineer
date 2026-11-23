// IBM PC AT 5170 system unit without its display adapter: the system board
// (ibm_pc_at_5170), the I/O channel's 8-bit device cycles (at_io_channel)
// and the IBM Fixed Disk and Diskette Drive Adapter's diskette function
// (at_diskette_adapter) in an expansion slot. One more slot, for the
// display adapter, is brought out; ibm_pc_at_5170_ega and
// ibm_pc_at_5170_vga put their card there, so the board, channel and
// diskette wiring exist once.
//
// Slot wiring (Technical Reference, I/O channel, sheet 20): every card sees
// SA0-SA19, SD0-SD7, -IOR, -IOW, -SMEMR, -SMEMW and AEN. -IOR and -IOW are
// driven by the processor's channel cycles or by the DMA controller; during
// a DMA transfer SD0-SD7 carries the transferred byte. DRQ2/-DACK2 and T/C
// go to the diskette adapter, its interrupt to IRQ 6 and the display card's
// IRQ2 to IRQ 9 (on the AT the channel's IRQ 2 pin is IRQ 9, sheet 16).
// AEN is the board's HLDA, high for refresh and DMA cycles, as the display
// machines had it before the adapter was fitted.
module at_system_unit #(
    parameter KBC_ROM_FILE = "",
    parameter RTC_NVRAM_FILE = "",
    parameter int unsigned CPU_HZ = 6_000_000
) (
    input  logic        clk_i, clk_2x_i, reset_i, ready_n_i,
    input  logic        dma_clk_n_i, hold_permit_i, refresh_ready_i,
    input  logic [2:0]  timer_clk_i,
    input  logic [15:0] mem_rdata_i,
    input  logic        kbd_unlocked_i, display_mono_i, mfg_jumper_i, ram_512k_i,
    input  logic        kbd_clk_i, kbd_data_i,
    input  logic [15:0] chan_irq_i,
    output logic        kbd_clk_o, kbd_data_o,
    output logic [23:0] address_o,
    output logic [15:0] data_o,
    output logic        data_oe_o, address_oe_o, bhe_n_o,
    output logic        io_cycle_o, fetch_cycle_o,
    output logic [1:0]  completed_bytes_o,
    output logic        hlda_o, cycle_active_o, protocol_error_o,
    output logic        halted_o, shutdown_o, fault_o,
    output logic        refresh_o, refresh_ras_trigger_o,
    output logic        refresh_memr_n_o, refresh_memr_oe_o,
    output logic        io_unclaimed_o, io_read_undriven_o,
    output logic [15:0] io_port_o,
    output logic [7:0]  post_code_o,
    output logic        a20_gate_o, rc_n_o, kbc_obf_o, cpu_reset_o, kbc_illegal_o,
    output logic        nmi_enable_o, irq8_o, intr_o, inta_cycle_o,
    output logic        dma_mem_o, dma_mem_write_o,
    output logic        chan_sel_o, chan_driven_o,
    // The display adapter's slot.
    output logic [19:0] sa_o,
    output logic [7:0]  sd_o,
    input  logic [7:0]  vid_d_i,
    input  logic        vid_d_oe_i,
    output logic        smemr_n_o, smemw_n_o, ior_n_o, iow_n_o,
    input  logic        vid_irq2_i,
    // Diskette drive cable and decoded media (at_diskette_adapter).
    output logic [1:0]  fd_select_o, fd_motor_o,
    output logic        fd_step_o, fd_direction_o, fd_head_o,
    output logic [1:0]  fd_rate_o,
    input  logic        fd_track0_i, fd_write_protect_i, fd_change_i,
    output logic        fd_active_o, fd_write_o, fd_format_o, fd_mfm_o,
    input  logic        fd_index_i, fd_header_i,
    input  logic [7:0]  fd_c_i, fd_h_i, fd_r_i, fd_n_i,
    input  logic        fd_byte_valid_i,
    input  logic [7:0]  fd_byte_i,
    input  logic        fd_end_i, fd_slot_i,
    output logic        fd_sector_begin_o, fd_sector_end_o, fd_tx_valid_o,
    output logic [7:0]  fd_tx_byte_o, fd_sector_r_o
);
    logic mem_cycle, chan_ready, chan_ior_n, chan_iow_n;
    logic [15:0] chan_rdata, chan_irq;
    logic [7:0]  chan_sd, fdc_d, slot_d;
    logic        fdc_d_oe, slot_d_oe, fdc_drq, fdc_irq, tc, aen_unused;
    logic        dma_ior_n, dma_iow_n;
    logic [3:0]  dack_n;

    always_comb begin
        chan_irq = chan_irq_i;
        if (vid_irq2_i) chan_irq[9] = 1'b1;
        if (fdc_irq) chan_irq[6] = 1'b1;
    end

    /* verilator lint_off PINMISSING */
    ibm_pc_at_5170 #(
        .KBC_ROM_FILE(KBC_ROM_FILE), .RTC_NVRAM_FILE(RTC_NVRAM_FILE), .CPU_HZ(CPU_HZ)
    ) board (
        .clk_i, .clk_2x_i, .reset_i,
        .ready_n_i(ready_n_i || (chan_sel_o && !chan_ready)),
        .dma_clk_n_i, .hold_permit_i, .refresh_ready_i, .timer_clk_i,
        .mem_rdata_i(chan_sel_o ? chan_rdata : mem_rdata_i),
        .kbd_unlocked_i, .display_mono_i, .mfg_jumper_i, .ram_512k_i, .kbd_clk_i, .kbd_data_i,
        .chan_irq_i(chan_irq),
        .kbd_clk_o, .kbd_data_o, .address_o, .data_o, .data_oe_o, .address_oe_o, .bhe_n_o,
        .io_cycle_o, .fetch_cycle_o, .completed_bytes_o, .hlda_o, .cycle_active_o,
        .protocol_error_o, .halted_o, .shutdown_o, .fault_o, .refresh_o,
        .refresh_ras_trigger_o, .refresh_memr_n_o, .refresh_memr_oe_o,
        .io_unclaimed_o, .io_read_undriven_o, .io_port_o, .post_code_o,
        .a20_gate_o, .rc_n_o, .kbc_obf_o, .cpu_reset_o, .kbc_illegal_o,
        .nmi_enable_o, .irq8_o, .intr_o, .inta_cycle_o, .mem_cycle_o(mem_cycle),
        .dma_drq_i({1'b0, fdc_drq, 2'b00}), .dma_io_rdata_i(fdc_d_oe ? fdc_d : 8'hff),
        .dma_mem_o, .dma_mem_write_o, .dma_ior_n_o(dma_ior_n), .dma_iow_n_o(dma_iow_n),
        .aen_o(aen_unused), .tc_o(tc), .dack_n_o(dack_n)
    );
    /* verilator lint_on PINMISSING */

    at_io_channel channel (
        .clk_i, .reset_i,
        .mem_cycle_i(mem_cycle), .io_unclaimed_i(io_unclaimed_o),
        .address_i(address_o), .io_port_i(io_port_o), .bhe_n_i(bhe_n_o),
        .write_i(data_oe_o), .wdata_i(data_o),
        .sel_o(chan_sel_o), .ready_o(chan_ready), .rdata_o(chan_rdata),
        .sa_o(sa_o), .sd_o(chan_sd), .sd_i(slot_d), .sd_oe_i(slot_d_oe),
        .smemr_n_o, .smemw_n_o, .ior_n_o(chan_ior_n), .iow_n_o(chan_iow_n)
    );

    // Slot buses. During a DMA transfer (HLDA, AEN high) the board puts the
    // byte on its data bus and the 8237 drives -IOR/-IOW.
    assign ior_n_o = chan_ior_n && dma_ior_n;
    assign iow_n_o = chan_iow_n && dma_iow_n;
    assign sd_o = hlda_o ? data_o[7:0] : chan_sd;
    assign slot_d = fdc_d_oe ? fdc_d : vid_d_i;
    assign slot_d_oe = fdc_d_oe || vid_d_oe_i;

    // A card drove the bus at some point of the current channel cycle.
    always_ff @(posedge clk_i) begin
        if (reset_i || !chan_sel_o) chan_driven_o <= 1'b0;
        else if (slot_d_oe) chan_driven_o <= 1'b1;
    end

    at_diskette_adapter #(.CLK_HZ(CPU_HZ)) diskette (
        .clk_i, .reset_drv_i(reset_i),
        .a_i(sa_o), .d_i(sd_o), .d_o(fdc_d), .d_oe_o(fdc_d_oe),
        .ior_n_i(ior_n_o), .iow_n_i(iow_n_o), .aen_i(hlda_o),
        .drq2_o(fdc_drq), .dack2_n_i(dack_n[2]), .tc_i(tc), .irq6_o(fdc_irq),
        .drive_select_o(fd_select_o), .motor_on_o(fd_motor_o),
        .step_o(fd_step_o), .direction_o(fd_direction_o), .head_o(fd_head_o),
        .data_rate_o(fd_rate_o),
        .track0_i(fd_track0_i), .write_protect_i(fd_write_protect_i), .disk_change_i(fd_change_i),
        .media_active_o(fd_active_o), .media_write_o(fd_write_o), .media_format_o(fd_format_o),
        .mfm_o(fd_mfm_o),
        .index_i(fd_index_i), .header_valid_i(fd_header_i),
        .header_c_i(fd_c_i), .header_h_i(fd_h_i), .header_r_i(fd_r_i), .header_n_i(fd_n_i),
        .media_byte_valid_i(fd_byte_valid_i), .media_byte_i(fd_byte_i),
        .media_end_i(fd_end_i), .write_slot_i(fd_slot_i),
        .sector_begin_o(fd_sector_begin_o), .sector_end_o(fd_sector_end_o),
        .tx_valid_o(fd_tx_valid_o), .tx_byte_o(fd_tx_byte_o), .sector_r_o(fd_sector_r_o)
    );

    logic unused;
    assign unused = ^{aen_unused, dack_n[3], dack_n[1:0]};
endmodule

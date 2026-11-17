// Simulation wrapper: the system board with an EGA card, plus
// verification-only taps of the
// CPU's retirement state and read data. The taps use hierarchical
// references, so this wrapper is not synthesized.
module ibm_pc_at_5170_ega_tb #(
    parameter KBC_ROM_FILE = "",
    parameter RTC_NVRAM_FILE = "",
    parameter EGA_ROM_FILE = ""
) (
    input  logic        clk_i, clk_2x_i, vid_clk_i, reset_i, ready_n_i,
    input  logic [3:0]  ega_sw_i,
    input  logic        ega_p1_i, ega_p3_i,
    output logic        chan_sel_o, chan_driven_o, pix_en_o, hsync_o, vsync_o, blank_o, de_o,
    output logic [5:0]  video_o,
    input  logic        dma_clk_n_i, hold_permit_i, refresh_ready_i,
    input  logic [2:0]  timer_clk_i,
    input  logic [15:0] mem_rdata_i,
    input  logic        kbd_unlocked_i, display_mono_i, mfg_jumper_i, ram_512k_i,
    input  logic        kbd_clk_i, kbd_data_i,
    input  logic [15:0] chan_irq_i,
    output logic [23:0] address_o,
    output logic [15:0] data_o, cpu_data_o,
    output logic        data_oe_o, address_oe_o, bhe_n_o, io_cycle_o, fetch_cycle_o,
    output logic [1:0]  completed_bytes_o,
    output logic        hlda_o, cycle_active_o, protocol_error_o,
    output logic        halted_o, shutdown_o, fault_o,
    output logic        refresh_o, refresh_ras_trigger_o,
    output logic        refresh_memr_n_o, refresh_memr_oe_o,
    output logic        io_unclaimed_o, io_read_undriven_o,
    output logic [15:0] io_port_o,
    output logic [7:0]  post_code_o,
    output logic        a20_gate_o, rc_n_o, kbc_obf_o, cpu_reset_o, kbc_illegal_o,
    output logic        kbd_clk_o, kbd_data_o, nmi_enable_o, irq8_o, intr_o, inta_cycle_o,
    output logic        rtc_tick_o, rtc_as_fall_o, rtc_wr_end_o, rtc_rd_end_o,
    output logic [7:0]  rtc_ad_o,
    output logic        kbc_retire_o, kbc_start_o, kbc_wr_end_o, kbc_rd_end_o,
    output logic        kbc_wr_a0_o, kbc_rd_a0_o,
    output logic [7:0]  kbc_wr_data_o,
    output logic [10:0] kbc_retire_pc_o,
    output logic [7:0]  kbc_status_o, kbc_p2_o,
    // DMA memory transfers and the diskette drive cable (see at_system_unit).
    output logic        dma_mem_o, dma_mem_write_o,
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
    output logic [7:0]  fd_tx_byte_o, fd_sector_r_o,
    output logic        fd_irq6_o, fd_drq2_o, fd_tc_o,
    output logic        retire_o,
    output logic [23:0] retire_pc_o,
    output logic [7:0]  retire_opcode_o,
    output logic [127:0] regs_o,
    output logic [63:0] segs_o,
    output logic [15:0] ip_o, flags_o
);
    /* verilator lint_off PINMISSING */
    ibm_pc_at_5170_ega #(.KBC_ROM_FILE(KBC_ROM_FILE), .RTC_NVRAM_FILE(RTC_NVRAM_FILE),
                         .EGA_ROM_FILE(EGA_ROM_FILE)) machine (
        .vid_clk_i, .ega_sw_i, .ega_p1_i, .ega_p3_i, .chan_sel_o, .chan_driven_o,
        .pix_en_o, .video_o, .hsync_o, .vsync_o, .blank_o, .de_o,
        .clk_i, .clk_2x_i, .reset_i, .ready_n_i, .dma_clk_n_i, .hold_permit_i,
        .refresh_ready_i, .timer_clk_i, .mem_rdata_i, .address_o, .data_o,
        .data_oe_o, .address_oe_o, .bhe_n_o, .io_cycle_o, .fetch_cycle_o, .completed_bytes_o, .hlda_o,
        .cycle_active_o, .protocol_error_o, .halted_o, .shutdown_o, .fault_o,
        .refresh_o, .refresh_ras_trigger_o, .refresh_memr_n_o, .refresh_memr_oe_o,
        .io_unclaimed_o, .io_read_undriven_o, .io_port_o, .post_code_o,
        .kbd_unlocked_i, .display_mono_i, .mfg_jumper_i, .ram_512k_i, .kbd_clk_i, .kbd_data_i,
        .kbd_clk_o, .kbd_data_o, .a20_gate_o, .rc_n_o, .kbc_obf_o, .cpu_reset_o, .kbc_illegal_o,
        .nmi_enable_o, .irq8_o, .chan_irq_i, .intr_o, .inta_cycle_o,
        .dma_mem_o, .dma_mem_write_o,
        .fd_select_o, .fd_motor_o, .fd_step_o, .fd_direction_o, .fd_head_o, .fd_rate_o,
        .fd_track0_i, .fd_write_protect_i, .fd_change_i,
        .fd_active_o, .fd_write_o, .fd_format_o, .fd_mfm_o, .fd_index_i, .fd_header_i,
        .fd_c_i, .fd_h_i, .fd_r_i, .fd_n_i, .fd_byte_valid_i, .fd_byte_i, .fd_end_i, .fd_slot_i,
        .fd_sector_begin_o, .fd_sector_end_o, .fd_tx_valid_o, .fd_tx_byte_o, .fd_sector_r_o
    );
    /* verilator lint_on PINMISSING */
    // Diskette adapter lines, for the bench's logs.
    assign fd_irq6_o = machine.unit.fdc_irq;
    assign fd_drq2_o = machine.unit.fdc_drq;
    assign fd_tc_o = machine.unit.tc;
    assign cpu_data_o = machine.unit.board.cpu_data;
    assign kbc_retire_o = machine.unit.board.kbc.retire_o;
    assign kbc_retire_pc_o = machine.unit.board.kbc.retire_pc_o;
    // MC146818 events: an oscillator period, and the clock edges at which
    // an address strobe, a write and a read take effect (rtc_ad_o is the
    // bus value the chip sampled for the strobe or write).
    assign rtc_tick_o = machine.unit.board.rtc_tick;
    assign rtc_as_fall_o = machine.unit.board.rtc.as_fall;
    assign rtc_wr_end_o = machine.unit.board.rtc.wr_end;
    assign rtc_rd_end_o = machine.unit.board.rtc.rd_end;
    assign rtc_ad_o = machine.unit.board.rtc.ad_q;
    // An 8042 instruction (or interrupt vector) starts in a machine cycle
    // whose sequencer state is S_FETCH (encoding 0); host-bus effects apply
    // at the clock edge where wr_end/rd_end are high.
    assign kbc_start_o = machine.unit.board.kbc_ce && machine.unit.board.kbc.core.state == 2'd0;
    assign kbc_wr_end_o = machine.unit.board.kbc.core.wr_end;
    assign kbc_rd_end_o = machine.unit.board.kbc.core.rd_end;
    assign kbc_wr_a0_o = machine.unit.board.kbc.core.wr_a0_q;
    assign kbc_rd_a0_o = machine.unit.board.kbc.core.rd_a0_q;
    assign kbc_wr_data_o = machine.unit.board.kbc.core.wr_d_q;
    assign kbc_status_o = machine.unit.board.kbc.core.sts;
    assign kbc_p2_o = machine.unit.board.kbc.p2_o;
    assign retire_o = machine.unit.board.cpu.core.retire_o;
    assign retire_pc_o = machine.unit.board.cpu.core.retire_pc_o;
    assign retire_opcode_o = machine.unit.board.cpu.core.retire_opcode_o;
    assign regs_o = machine.unit.board.cpu.core.regs_o;
    assign segs_o = machine.unit.board.cpu.core.segs_o;
    assign ip_o = machine.unit.board.cpu.core.ip_o;
    assign flags_o = machine.unit.board.cpu.core.flags_o;
endmodule

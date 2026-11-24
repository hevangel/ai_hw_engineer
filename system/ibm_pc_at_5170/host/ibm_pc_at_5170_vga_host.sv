// Web-host wrapper of the IBM PC AT 5170 with the VGA card.
//
// The machine (src/ibm_pc_at_5170_vga.sv) is instantiated unchanged. The
// wrapper adds read-only taps of the 80286's retirement state and read data
// (hierarchical references, so it is simulation-only and never
// synthesized) and nothing else. It is the top of host/simulator.cpp.
//
// Built with --trace-depth 1, so a waveform capture records exactly the
// signals of this module: its ports and the named taps below. The groups
// are listed in system/ibm_pc_at_5170/README.md (Web interface and waveform).
module ibm_pc_at_5170_vga_host #(
    parameter KBC_ROM_FILE = "",
    parameter RTC_NVRAM_FILE = "",
    parameter VGA_ROM_FILE = ""
) (
    // Clocks and board inputs, driven by the simulator exactly as by
    // tb/post_runner.cpp.
    input  logic        clk_i, clk_2x_i, vid_clk_i, reset_i, ready_n_i,
    input  logic        dma_clk_n_i, hold_permit_i, refresh_ready_i,
    input  logic [2:0]  timer_clk_i,
    input  logic [15:0] mem_rdata_i,
    input  logic        kbd_unlocked_i, display_mono_i, mfg_jumper_i, ram_512k_i,
    // Keyboard connector, open collector: 1 = the keyboard releases the line.
    input  logic        kbd_clk_i, kbd_data_i,
    input  logic [15:0] chan_irq_i,
    // Keyboard lines as the keyboard sees them.
    output logic        kbd_clk_o, kbd_data_o,
    // Processor bus.
    output logic [23:0] address_o,
    output logic [15:0] data_o, cpu_data_o,
    output logic        data_oe_o, bhe_n_o, io_cycle_o, fetch_cycle_o,
    output logic [1:0]  completed_bytes_o,
    output logic        hlda_o, dma_mem_o, dma_mem_write_o,
    output logic        protocol_error_o, halted_o, fault_o, refresh_o,
    output logic        io_unclaimed_o, io_read_undriven_o,
    output logic [15:0] io_port_o,
    output logic [7:0]  post_code_o,
    output logic        kbc_obf_o, cpu_reset_o, kbc_illegal_o, intr_o, inta_cycle_o,
    output logic        chan_sel_o, chan_driven_o,
    // Diskette drive cable.
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
    // Monitor connector.
    output logic        pix_en_o, hsync_o, vsync_o, de_o,
    output logic [5:0]  r_o, g_o, b_o,
    // 80286 retirement taps.
    output logic        retire_o,
    output logic [15:0] cs_o, ip_o, flags_o,
    // Trace taps for the Unicorn replay (--trace, the records of
    // tb/post_runner.cpp): retired PC and opcode, registers, segments and
    // the 8042's A20 GATE output.
    output logic [23:0] retire_pc_o,
    output logic [7:0]  retire_opcode_o,
    output logic [127:0] regs_o,
    output logic [63:0] segs_o,
    output logic        a20_gate_o,
    // 8042 port 2 (P26 drives the keyboard clock low through an inverter,
    // P27 drives data).
    output logic [7:0]  kbc_p2_o
);

    /* verilator lint_off PINMISSING */
    ibm_pc_at_5170_vga #(.KBC_ROM_FILE(KBC_ROM_FILE), .RTC_NVRAM_FILE(RTC_NVRAM_FILE),
                         .VGA_ROM_FILE(VGA_ROM_FILE)) machine (
        .vid_clk_i, .chan_sel_o, .chan_driven_o,
        .pix_en_o, .r_o, .g_o, .b_o, .hsync_o, .vsync_o, .de_o,
        .clk_i, .clk_2x_i, .reset_i, .ready_n_i, .dma_clk_n_i, .hold_permit_i,
        .refresh_ready_i, .timer_clk_i, .mem_rdata_i, .address_o, .data_o,
        .data_oe_o, .bhe_n_o, .io_cycle_o, .fetch_cycle_o, .completed_bytes_o, .hlda_o,
        .protocol_error_o, .halted_o, .fault_o, .refresh_o,
        .io_unclaimed_o, .io_read_undriven_o, .io_port_o, .post_code_o, .a20_gate_o,
        .kbd_unlocked_i, .display_mono_i, .mfg_jumper_i, .ram_512k_i, .kbd_clk_i, .kbd_data_i,
        .kbd_clk_o, .kbd_data_o, .kbc_obf_o, .cpu_reset_o, .kbc_illegal_o,
        .chan_irq_i, .intr_o, .inta_cycle_o,
        .dma_mem_o, .dma_mem_write_o,
        .fd_select_o, .fd_motor_o, .fd_step_o, .fd_direction_o, .fd_head_o, .fd_rate_o,
        .fd_track0_i, .fd_write_protect_i, .fd_change_i,
        .fd_active_o, .fd_write_o, .fd_format_o, .fd_mfm_o, .fd_index_i, .fd_header_i,
        .fd_c_i, .fd_h_i, .fd_r_i, .fd_n_i, .fd_byte_valid_i, .fd_byte_i, .fd_end_i, .fd_slot_i,
        .fd_sector_begin_o, .fd_sector_end_o, .fd_tx_valid_o, .fd_tx_byte_o, .fd_sector_r_o
    );
    /* verilator lint_on PINMISSING */
    assign cpu_data_o = machine.unit.board.cpu_data;
    assign retire_o = machine.unit.board.cpu.core.retire_o;
    assign retire_pc_o = machine.unit.board.cpu.core.retire_pc_o;
    assign retire_opcode_o = machine.unit.board.cpu.core.retire_opcode_o;
    assign regs_o = machine.unit.board.cpu.core.regs_o;
    assign segs_o = machine.unit.board.cpu.core.segs_o;

    assign cs_o = machine.unit.board.cpu.core.segs_o[31:16];
    assign ip_o = machine.unit.board.cpu.core.ip_o;
    assign flags_o = machine.unit.board.cpu.core.flags_o;
    assign kbc_p2_o = machine.unit.board.kbc.p2_o;
    assign fd_irq6_o = machine.unit.fdc_irq;
    assign fd_drq2_o = machine.unit.fdc_drq;
    assign fd_tc_o = machine.unit.tc;
endmodule

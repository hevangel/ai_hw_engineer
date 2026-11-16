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
    output logic        protocol_error_o, halted_o, fault_o, refresh_o,
    output logic        io_unclaimed_o, io_read_undriven_o,
    output logic [15:0] io_port_o,
    output logic [7:0]  post_code_o,
    output logic        kbc_obf_o, cpu_reset_o, kbc_illegal_o, intr_o, inta_cycle_o,
    output logic        chan_sel_o, chan_driven_o,
    // Monitor connector.
    output logic        pix_en_o, hsync_o, vsync_o, de_o,
    output logic [5:0]  r_o, g_o, b_o,
    // 80286 retirement taps.
    output logic        retire_o,
    output logic [15:0] cs_o, ip_o, flags_o,
    // 8042 port 2 (P26 drives the keyboard clock low through an inverter,
    // P27 drives data).
    output logic [7:0]  kbc_p2_o
);
    logic [63:0] segs;
    /* verilator lint_off PINMISSING */
    ibm_pc_at_5170_vga #(.KBC_ROM_FILE(KBC_ROM_FILE), .RTC_NVRAM_FILE(RTC_NVRAM_FILE),
                         .VGA_ROM_FILE(VGA_ROM_FILE)) machine (
        .vid_clk_i, .chan_sel_o, .chan_driven_o,
        .pix_en_o, .r_o, .g_o, .b_o, .hsync_o, .vsync_o, .de_o,
        .clk_i, .clk_2x_i, .reset_i, .ready_n_i, .dma_clk_n_i, .hold_permit_i,
        .refresh_ready_i, .timer_clk_i, .mem_rdata_i, .address_o, .data_o,
        .data_oe_o, .bhe_n_o, .io_cycle_o, .fetch_cycle_o, .completed_bytes_o,
        .protocol_error_o, .halted_o, .fault_o, .refresh_o,
        .io_unclaimed_o, .io_read_undriven_o, .io_port_o, .post_code_o,
        .kbd_unlocked_i, .display_mono_i, .mfg_jumper_i, .ram_512k_i, .kbd_clk_i, .kbd_data_i,
        .kbd_clk_o, .kbd_data_o, .kbc_obf_o, .cpu_reset_o, .kbc_illegal_o,
        .chan_irq_i, .intr_o, .inta_cycle_o
    );
    /* verilator lint_on PINMISSING */
    assign cpu_data_o = machine.board.cpu_data;
    assign retire_o = machine.board.cpu.core.retire_o;
    assign segs = machine.board.cpu.core.segs_o;
    assign cs_o = segs[31:16];
    assign ip_o = machine.board.cpu.core.ip_o;
    assign flags_o = machine.board.cpu.core.flags_o;
    assign kbc_p2_o = machine.board.kbc.p2_o;
endmodule

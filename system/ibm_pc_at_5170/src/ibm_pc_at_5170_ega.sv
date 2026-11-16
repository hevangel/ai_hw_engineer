// IBM PC AT 5170 with an IBM Enhanced Graphics Adapter in an expansion slot.
//
// The system board (ibm_pc_at_5170) is unchanged. This level adds the I/O
// channel's 8-bit device cycles (at_io_channel) and one card, the IBM EGA
// (design/ibm_ega), and wires the card's IRQ2 to the board's IRQ 9 (on the
// AT the channel's IRQ 2 pin is IRQ 9, Technical Reference sheet 16).
//
// Clocks: the board runs on clk_i/clk_2x_i. The card is a clock-enable
// design on vid_clk_i, which must be an integer multiple of clk_i with
// aligned edges (VID_CLK_HZ / CPU_HZ, 4 by default) so that the slot
// signals are synchronous to both. The 14.31818 MHz OSC line of the channel
// and the card's own 16.257 MHz crystal are clock enables derived from
// vid_clk_i by phase accumulators, so their average rates are exact
// relative to the processor clock and their edges are quantized to
// vid_clk_i (ASSUMPTION AT19, see spec).
//
// Memory and unanswered I/O that do not belong to the channel still come
// from the host on mem_rdata_i, as for the bare board.
module ibm_pc_at_5170_ega #(
    parameter KBC_ROM_FILE = "",
    parameter RTC_NVRAM_FILE = "",
    parameter EGA_ROM_FILE = "",
    parameter int unsigned CPU_HZ = 6_000_000,
    parameter int unsigned VID_CLK_HZ = 24_000_000,
    parameter int unsigned OSC_HZ = 14_318_180,
    parameter int unsigned EGA_XTAL_HZ = 16_257_000
) (
    input  logic        clk_i, clk_2x_i, vid_clk_i, reset_i, ready_n_i,
    input  logic        dma_clk_n_i, hold_permit_i, refresh_ready_i,
    input  logic [2:0]  timer_clk_i,
    input  logic [15:0] mem_rdata_i,
    input  logic        kbd_unlocked_i, display_mono_i, mfg_jumper_i, ram_512k_i,
    input  logic        kbd_clk_i, kbd_data_i,
    input  logic [15:0] chan_irq_i,
    // EGA configuration switches SW1-SW4 (1 = off/open) and jumpers P1, P3.
    input  logic [3:0]  ega_sw_i,
    input  logic        ega_p1_i, ega_p3_i,
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
    // DMA memory transfers (see ibm_pc_at_5170) and the diskette drive
    // cable with its decoded media (see at_diskette_adapter).
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
    // I/O channel activity, for the bench.
    output logic        chan_sel_o,        // the current cycle belongs to the channel
    output logic        chan_driven_o,     // a card drove SD0-SD7 in the command phase
    // Direct-drive monitor connector, sampled on vid_clk_i when pix_en_o.
    output logic        pix_en_o,
    output logic [5:0]  video_o,
    output logic        hsync_o, vsync_o, blank_o, de_o
);
    logic [19:0] sa;
    logic [7:0]  sd_out, card_d;
    logic        card_d_oe, smemr_n, smemw_n, ior_n, iow_n;
    logic        card_irq2, card_irq2_oe;

    /* verilator lint_off PINMISSING */
    at_system_unit #(
        .KBC_ROM_FILE(KBC_ROM_FILE), .RTC_NVRAM_FILE(RTC_NVRAM_FILE), .CPU_HZ(CPU_HZ)
    ) unit (
        .clk_i, .clk_2x_i, .reset_i, .ready_n_i,
        .dma_clk_n_i, .hold_permit_i, .refresh_ready_i, .timer_clk_i, .mem_rdata_i,
        .kbd_unlocked_i, .display_mono_i, .mfg_jumper_i, .ram_512k_i, .kbd_clk_i, .kbd_data_i,
        .chan_irq_i,
        .kbd_clk_o, .kbd_data_o, .address_o, .data_o, .data_oe_o, .address_oe_o, .bhe_n_o,
        .io_cycle_o, .fetch_cycle_o, .completed_bytes_o, .hlda_o, .cycle_active_o,
        .protocol_error_o, .halted_o, .shutdown_o, .fault_o, .refresh_o,
        .refresh_ras_trigger_o, .refresh_memr_n_o, .refresh_memr_oe_o,
        .io_unclaimed_o, .io_read_undriven_o, .io_port_o, .post_code_o,
        .a20_gate_o, .rc_n_o, .kbc_obf_o, .cpu_reset_o, .kbc_illegal_o,
        .nmi_enable_o, .irq8_o, .intr_o, .inta_cycle_o, .dma_mem_o, .dma_mem_write_o,
        .chan_sel_o, .chan_driven_o,
        .sa_o(sa), .sd_o(sd_out), .vid_d_i(card_d), .vid_d_oe_i(card_d_oe),
        .smemr_n_o(smemr_n), .smemw_n_o(smemw_n), .ior_n_o(ior_n), .iow_n_o(iow_n),
        .vid_irq2_i(card_irq2_oe && card_irq2),
        .fd_select_o, .fd_motor_o, .fd_step_o, .fd_direction_o, .fd_head_o, .fd_rate_o,
        .fd_track0_i, .fd_write_protect_i, .fd_change_i,
        .fd_active_o, .fd_write_o, .fd_format_o, .fd_mfm_o, .fd_index_i, .fd_header_i,
        .fd_c_i, .fd_h_i, .fd_r_i, .fd_n_i, .fd_byte_valid_i, .fd_byte_i, .fd_end_i, .fd_slot_i,
        .fd_sector_begin_o, .fd_sector_end_o, .fd_tx_valid_o, .fd_tx_byte_o, .fd_sector_r_o
    );
    /* verilator lint_on PINMISSING */

    // Oscillator clock enables on vid_clk_i.
    logic [31:0] osc_acc, xtal_acc;
    logic osc_ce, xtal_ce;
    always_ff @(posedge vid_clk_i) begin
        if (reset_i) begin
            osc_acc <= '0; xtal_acc <= '0; osc_ce <= 1'b0; xtal_ce <= 1'b0;
        end else begin
            if (osc_acc + OSC_HZ >= VID_CLK_HZ) begin
                osc_acc <= osc_acc + OSC_HZ - VID_CLK_HZ; osc_ce <= 1'b1;
            end else begin
                osc_acc <= osc_acc + OSC_HZ; osc_ce <= 1'b0;
            end
            if (xtal_acc + EGA_XTAL_HZ >= VID_CLK_HZ) begin
                xtal_acc <= xtal_acc + EGA_XTAL_HZ - VID_CLK_HZ; xtal_ce <= 1'b1;
            end else begin
                xtal_acc <= xtal_acc + EGA_XTAL_HZ; xtal_ce <= 1'b0;
            end
        end
    end

    /* verilator lint_off PINMISSING */
    ibm_ega #(.ROM_FILE(EGA_ROM_FILE)) ega (
        .clk(vid_clk_i), .rst_n(!reset_i), .reset_drv_i(reset_i),
        .a_i(sa), .d_i(sd_out), .d_o(card_d), .d_oe_o(card_d_oe),
        .ior_n_i(ior_n), .iow_n_i(iow_n), .memr_n_i(smemr_n), .memw_n_i(smemw_n),
        .aen_i(hlda_o), .dack0_n_i(1'b1),
        .irq2_o(card_irq2), .irq2_oe_o(card_irq2_oe),
        .osc14_ce_i(osc_ce), .osc16_ce_i(xtal_ce), .ext_osc_ce_i(1'b0),
        .sw_i(ega_sw_i), .p1_i(ega_p1_i), .p3_i(ega_p3_i),
        .feat_i(2'b00), .lpen_n_i(1'b1), .lpen_sw_n_i(1'b1),
        .pix_en_o, .video_o, .hsync_o, .vsync_o, .blank_o, .de_o,
        .dbg_reg_addr_i(8'h00), .dbg_plane_i(2'b00), .dbg_mem_addr_i(16'h0000)
    );
    /* verilator lint_on PINMISSING */
endmodule

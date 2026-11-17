// IBM PC AT 5170 with an IBM PS/2 Display Adapter (VGA) in an expansion slot.
//
// The same arrangement as ibm_pc_at_5170_ega: the unchanged system board,
// the I/O channel's 8-bit device cycles (at_io_channel) and one card, here
// the IBM VGA (design/ibm_vga). The card's IRQ2 goes to the board's IRQ 9.
//
// Clocks: the card is a clock-enable design on vid_clk_i and needs a clock
// at least as fast as its 28.322 MHz oscillator, so vid_clk_i is twice the
// processor clock and stands for 48 MHz (the processor clock stands for
// 24 MHz, ASSUMPTION AT19). The card's 25.175 MHz and 28.322 MHz
// oscillators are clock enables derived from vid_clk_i by phase
// accumulators.
//
// A colour analog monitor is attached: all three DAC outputs are loaded
// (load_i = 111), which is what the adapter BIOS senses.
module ibm_pc_at_5170_vga #(
    parameter KBC_ROM_FILE = "",
    parameter RTC_NVRAM_FILE = "",
    parameter VGA_ROM_FILE = "",
    parameter int unsigned CPU_HZ = 6_000_000,
    parameter int unsigned VID_CLK_HZ = 48_000_000,
    parameter int unsigned OSC25_HZ = 25_175_000,
    parameter int unsigned OSC28_HZ = 28_322_000
) (
    input  logic        clk_i, clk_2x_i, vid_clk_i, reset_i, ready_n_i,
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
    // I/O channel activity, for the bench.
    output logic        chan_sel_o,        // the current cycle belongs to the channel
    output logic        chan_driven_o,     // a card drove SD0-SD7 in the command phase
    // Analog monitor connector as 6-bit DAC codes, sampled on vid_clk_i
    // when pix_en_o.
    output logic        pix_en_o,
    output logic [5:0]  r_o, g_o, b_o,
    output logic        hsync_o, vsync_o, blank_o, de_o
);
    logic mem_cycle, chan_ready;
    logic [15:0] chan_rdata;
    logic [19:0] sa;
    logic [7:0]  sd_out, card_d;
    logic        card_d_oe, smemr_n, smemw_n, ior_n, iow_n;
    logic        card_irq2, card_irq2_oe;
    logic [15:0] chan_irq;

    always_comb begin
        chan_irq = chan_irq_i;
        if (card_irq2_oe && card_irq2) chan_irq[9] = 1'b1;
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
        .nmi_enable_o, .irq8_o, .intr_o, .inta_cycle_o, .mem_cycle_o(mem_cycle)
    );
    /* verilator lint_on PINMISSING */

    at_io_channel channel (
        .clk_i, .reset_i,
        .mem_cycle_i(mem_cycle), .io_unclaimed_i(io_unclaimed_o),
        .address_i(address_o), .io_port_i(io_port_o), .bhe_n_i(bhe_n_o),
        .write_i(data_oe_o), .wdata_i(data_o),
        .sel_o(chan_sel_o), .ready_o(chan_ready), .rdata_o(chan_rdata),
        .sa_o(sa), .sd_o(sd_out), .sd_i(card_d), .sd_oe_i(card_d_oe),
        .smemr_n_o(smemr_n), .smemw_n_o(smemw_n), .ior_n_o(ior_n), .iow_n_o(iow_n)
    );

    // A card drove the bus at some point of the current channel cycle.
    always_ff @(posedge clk_i) begin
        if (reset_i || !chan_sel_o) chan_driven_o <= 1'b0;
        else if (card_d_oe) chan_driven_o <= 1'b1;
    end

    // Oscillator clock enables on vid_clk_i.
    logic [31:0] acc25, acc28;
    logic ce25, ce28;
    always_ff @(posedge vid_clk_i) begin
        if (reset_i) begin
            acc25 <= '0; acc28 <= '0; ce25 <= 1'b0; ce28 <= 1'b0;
        end else begin
            if (acc25 + OSC25_HZ >= VID_CLK_HZ) begin
                acc25 <= acc25 + OSC25_HZ - VID_CLK_HZ; ce25 <= 1'b1;
            end else begin
                acc25 <= acc25 + OSC25_HZ; ce25 <= 1'b0;
            end
            if (acc28 + OSC28_HZ >= VID_CLK_HZ) begin
                acc28 <= acc28 + OSC28_HZ - VID_CLK_HZ; ce28 <= 1'b1;
            end else begin
                acc28 <= acc28 + OSC28_HZ; ce28 <= 1'b0;
            end
        end
    end

    /* verilator lint_off PINMISSING */
    ibm_vga #(.ROM_FILE(VGA_ROM_FILE)) vga (
        .clk(vid_clk_i), .rst_n(!reset_i), .reset_drv_i(reset_i),
        .a_i(sa), .d_i(sd_out), .d_o(card_d), .d_oe_o(card_d_oe),
        .ior_n_i(ior_n), .iow_n_i(iow_n), .memr_n_i(smemr_n), .memw_n_i(smemw_n),
        .aen_i(hlda_o), .dack0_n_i(1'b1),
        .irq2_o(card_irq2), .irq2_oe_o(card_irq2_oe),
        .osc25_ce_i(ce25), .osc28_ce_i(ce28), .ext_osc_ce_i(1'b0),
        .load_i(3'b111),
        .pix_en_o, .r_o, .g_o, .b_o, .hsync_o, .vsync_o, .blank_o, .de_o,
        .dbg_reg_addr_i(8'h00), .dbg_plane_i(2'b00), .dbg_mem_addr_i(16'h0000),
        .dbg_dac_i(8'h00)
    );
    /* verilator lint_on PINMISSING */
endmodule

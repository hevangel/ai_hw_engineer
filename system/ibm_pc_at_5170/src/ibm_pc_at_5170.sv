// IBM PC AT 5170 type-1 system board, milestone M2.
//
// Composes the native 80286, the 8254 timer, port 61h, the refresh request
// path, two 8237 register interfaces, the 74LS612 page registers, the
// refresh page-map gating, the 8042 keyboard controller (U126) running
// IBM's 1503033 firmware and the MC146818 real-time clock and CMOS RAM
// (U117). The timer, port 61h, DMA, page and refresh modules
// are the 286 design's schematic-cited AT models
// (design/intel_80286/tb/intel_80286_at_*.sv), reused in place so there is
// one implementation. The 8042 is design/intel_mcs48/intel_8042 and the
// MC146818 is design/motorola_mc146818.
//
// Memory and the expansion slots are external: the host supplies read data
// on mem_rdata_i for the current memory cycle, and for an I/O read that no
// board device answers, and performs writes from data_o. address_o is the
// system address bus, after the A20 gate. I/O reads are served only by
// modeled devices. io_unclaimed_o flags an I/O cycle that no modeled device
// decodes, so a run stops at the first missing device instead of reading a
// guessed value.
//
// Not yet modeled: both 8259 interrupt controllers (INTR is tied low, so
// the 8042's output-buffer-full line and the clock's IRQ 8 are only
// outputs here, and the NMI mask has nothing to mask), DMA requests and transfers, DRAM, video, diskette
// and fixed disk.
module ibm_pc_at_5170 #(
    // $readmemh image of the 8042 firmware (IBM 1503033), one byte per line.
    parameter KBC_ROM_FILE = "",
    // 8042 machine cycle in processor clocks. The 8042 crystal input is the
    // 6 MHz PCLK (sheet 17) and a UPI-42 machine cycle is 15 crystal clocks
    // (Intel UPI-41A User's Manual p.2-10), so one machine cycle is 15
    // processor clocks.
    parameter int unsigned KBC_CYCLE_CLKS = 15,
    // $readmemh image of the MC146818's 64 battery-backed locations.
    parameter RTC_NVRAM_FILE = "",
    // The clock's 32.768 kHz oscillator (Y3, sheet 18) as a fraction of the
    // processor clock: one oscillator period every CPU_HZ / RTC_OSC_HZ
    // processor clocks.
    parameter int unsigned CPU_HZ = 6_000_000,
    parameter int unsigned RTC_OSC_HZ = 32_768
) (
    input  logic        clk_i, clk_2x_i, reset_i, ready_n_i,
    input  logic        dma_clk_n_i, hold_permit_i, refresh_ready_i,
    input  logic [2:0]  timer_clk_i,
    input  logic [15:0] mem_rdata_i,
    // Board switches and jumpers read by the 8042 input port (sheet 17).
    input  logic        kbd_unlocked_i,    // J20 keyboard lock: 1 = not inhibited (P17)
    input  logic        display_mono_i,    // SW1: 1 = monochrome, 0 = colour (P16)
    input  logic        mfg_jumper_i,      // 1 = manufacturing jumper installed (P15 low)
    input  logic        ram_512k_i,        // J18 pins 1-2: 2nd 256K enabled (P14 high)
    // Keyboard cable, open collector: 1 = the keyboard releases the line.
    input  logic        kbd_clk_i, kbd_data_i,
    // I/O channel interrupt request lines IRQ 3-7, 9-12, 14 and 15 (bits
    // 0-2, 8 and 13 are unused: those levels are on the system board).
    input  logic [15:0] chan_irq_i,
    output logic        kbd_clk_o, kbd_data_o,   // line levels as the keyboard sees them
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
    output logic [15:0] io_port_o,         // port of the current device-side byte cycle
    output logic [7:0]  post_code_o,
    output logic        a20_gate_o,        // 8042 P21
    output logic        rc_n_o,            // 8042 P20: low requests a CPU reset
    output logic        kbc_obf_o,         // 8042 P24, +OPT BUF FULL (to IRQ1)
    output logic        cpu_reset_o,
    output logic        kbc_illegal_o,     // 8042 executed an undefined opcode
    output logic        nmi_enable_o,      // port 70h bit 7 written 0
    output logic        irq8_o,            // MC146818 IRQ through U107 (to IRQ 8)
    output logic        intr_o,            // master 8259A INT, the 80286 INTR pin
    output logic        inta_cycle_o,      // an interrupt-acknowledge bus cycle is active
    output logic        mem_cycle_o        // a memory cycle is in its command phase
);
    logic mem_status;
    logic cod_inta, m_io, s1, s0, status_oe, hold, detect, refresh_n;
    logic io_req, io_accept, io_write;
    logic [7:0] io_wdata, map_data;
    logic [23:0] cpu_address;
    logic [15:0] cpu_data;
    logic timer_sel, timer_valid, port61_sel, port61_valid;
    logic dma_sel, dma_ctrl2, dma_valid, page_sel, page_valid;
    logic kbc_sel, kbc_valid, rtc_sel, rtc_as, rtc_ds, rtc_valid;
    logic [7:0] rtc_rdata;
    logic [7:0] timer_rdata, port61_rdata, dma_rdata, page_rdata, kbc_rdata;
    logic [3:0] port61_control;
    logic [2:0] timer_out;
    logic cpu_ready_n, shutdown_reset_n;
    logic [3:0] status;
    assign status = {cod_inta, m_io, s1, s0};

    always_ff @(posedge clk_i) begin
        if (cpu_reset_o) begin
            io_cycle_o <= 1'b0;
            fetch_cycle_o <= 1'b0;
            mem_status <= 1'b0;
        end else if (status_oe) begin
            io_cycle_o <= status == 4'h9 || status == 4'ha;
            fetch_cycle_o <= status == 4'hd;
            mem_status <= status == 4'h5 || status == 4'h6 || status == 4'hd;
        end
    end
    // A memory read, write or instruction-fetch cycle in its command phase,
    // for the I/O channel.
    assign mem_cycle_o = address_oe_o && !status_oe && mem_status;

    // I/O bus conversion. Every device on the system board is 8 bits wide.
    // The 80286 runs a word I/O instruction as one 16-bit cycle; the board
    // holds the processor not ready and gives the devices two byte cycles,
    // the even address with the low byte and then the odd address with the
    // high byte. The BIOS depends on it: OUT 82h,AX at F000:0C9A writes page
    // registers 82h and 83h. io_req, io_accept, io_addr and io_wdata are the
    // device-side byte cycle.
    // ASSUMPTION AT15 (see spec): the two byte cycles are separated by one
    // clock with no device selected; the conversion logic's own timing is
    // not modeled.
    logic cpu_io_req, cpu_io_done, word_io;
    logic [1:0] conv;            // 0 = low byte, 1 = gap, 2 = high byte
    logic [7:0] conv_low;        // low byte read in the first cycle
    logic [15:0] io_addr, dev_data;
    assign cpu_io_req = address_oe_o && !status_oe && io_cycle_o;
    assign cpu_io_done = completed_bytes_o != 2'd0;
    assign word_io = cpu_io_req && !bhe_n_o && !cpu_address[0];
    assign io_req = cpu_io_req && !(word_io && conv == 2'd1);
    assign io_accept = !word_io ? cpu_io_done :
                       conv == 2'd0 ? !ready_n_i : conv == 2'd2 && cpu_io_done;
    assign io_addr = {cpu_address[15:1], cpu_address[0] || (word_io && conv == 2'd2)};
    always_ff @(posedge clk_i) begin
        if (cpu_reset_o || !cpu_io_req) conv <= 2'd0;
        else if (word_io && conv == 2'd0 && !ready_n_i) begin
            conv <= 2'd1;
            conv_low <= dev_data[7:0];
        end else if (word_io && conv == 2'd1) conv <= 2'd2;
    end
    assign io_write = data_oe_o;
    assign io_wdata = io_addr[0] ? data_o[15:8] : data_o[7:0];

    // A20 gate, sheet 1: U129 (74F257) selects the CPU's A20 while A20 GATE
    // (8042 P21) is high and ground while it is low. Its output floats
    // during HLDA; the DMA/refresh address path is not modeled here.
    assign address_o = {cpu_address[23:21], cpu_address[20] & a20_gate_o, cpu_address[19:0]};

    // One device at a time drives the CPU's data pins during an I/O read;
    // memory reads come from the host.
    function automatic logic [15:0] lane(input logic [7:0] value);
        lane = io_addr[0] ? {value, 8'h00} : {8'h00, value};
    endfunction
    assign dev_data = port61_valid ? lane(port61_rdata) :
                      timer_valid  ? lane(timer_rdata) :
                      kbc_valid    ? lane(kbc_rdata) :
                      pic1_valid   ? lane(pic1_rdata) :
                      pic2_valid   ? lane(pic2_rdata) :
                      (inta_tc && pic1_oe) ? {8'h00, pic1_rdata} :
                      (inta_tc && pic2_oe) ? {8'h00, pic2_rdata} :
                      rtc_valid    ? lane(rtc_rdata) :
                      dma_valid    ? lane(dma_rdata) :
                      page_valid   ? lane(page_rdata) :
                      mem_rdata_i;
    assign cpu_data = (word_io && conv == 2'd2) ? {dev_data[15:8], conv_low} : dev_data;

    assign io_claimed_o = timer_sel || port61_sel || dma_sel || page_sel || kbc_sel || rtc_sel ||
                          pic1_sel || pic2_sel || copro_sel;
    assign io_unclaimed_o = io_req && !io_claimed_o;
    assign io_port_o = io_addr;
    // Checked when the read completes: a device's data is due at the end of
    // the cycle, not during its wait states.
    assign io_read_undriven_o = io_req && io_accept && !io_write &&
        ((timer_sel && !timer_valid) || (port61_sel && !port61_valid) ||
         (dma_sel && !dma_valid) || (page_sel && !page_valid));

    // Port 80h is the 74LS612 slot the BIOS uses for its manufacturing
    // checkpoints (for example MOV AL,0Ah / OUT 80h at F000:03A2). The value
    // is kept here only as an observation of that register.
    always_ff @(posedge clk_i) begin
        if (reset_i) post_code_o <= 8'h00;
        else if (io_req && io_accept && io_write && io_addr == 16'h0080) post_code_o <= io_wdata;
    end

    // ------------------------------- NMI mask and MC146818 (U117, sheet 18)
    // The decode PROM U115 (sheet 18) serves 070h-07Fh as well as the 8042:
    // it makes -NMI CS (to the NMI-mask flip-flop, sheet 3) and the
    // MC146818's AS, DS and R/W. The chip's AD0-AD7 are XD0-XD7.
    // ASSUMPTION AT9 (see spec): the PROM contents are not published. A write
    // to an even address 070h-07Eh is taken to strobe AS (latching the
    // CMOS address from data bits 5-0) and to load the NMI mask from data bit
    // 7; an access to an odd address 071h-07Fh strobes DS, with R/W from the
    // direction. A read of an even address is unclaimed. NMI is masked at
    // power-up.
    assign rtc_as = io_req && io_addr[9:4] == 6'h07 && !io_addr[0] && io_write;
    assign rtc_ds = io_req && io_addr[9:4] == 6'h07 && io_addr[0];
    assign rtc_sel = rtc_as || rtc_ds;
    assign rtc_valid = rtc_ds && io_accept && !io_write;
    always_ff @(posedge clk_i) begin
        if (reset_i) nmi_enable_o <= 1'b0;
        else if (rtc_as && io_accept) nmi_enable_o <= !io_wdata[7];
    end

    // 32.768 kHz oscillator enable from the processor clock.
    logic [$clog2(CPU_HZ)-1:0] rtc_phase;
    logic rtc_tick, rtc_irq_n, rtc_oe, rtc_sqw;
    logic [7:0] rtc_dbg;
    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            rtc_phase <= '0;
            rtc_tick <= 1'b0;
        end else if (32'(rtc_phase) + RTC_OSC_HZ >= CPU_HZ) begin
            rtc_phase <= $bits(rtc_phase)'(32'(rtc_phase) + RTC_OSC_HZ - CPU_HZ);
            rtc_tick <= 1'b1;
        end else begin
            rtc_phase <= $bits(rtc_phase)'(32'(rtc_phase) + RTC_OSC_HZ);
            rtc_tick <= 1'b0;
        end
    end

    // Sheet 18: CE is low while POWER GOOD (through U108); RESET and PS are
    // tied to the battery-backed supply through R28/C85, so a system reset
    // does not reach the chip's RESET pin; IRQ has a 10K pull-up and goes
    // through inverter U107 to IRQ 8 (sheet 16); SQW and CKOUT are not
    // connected.
    motorola_mc146818 #(.NVRAM_FILE(RTC_NVRAM_FILE)) rtc (
        .clk(clk_i), .rst_n(!reset_i), .tick_i(rtc_tick),
        .ce_n_i(1'b0), .as_i(rtc_as), .ds_i(rtc_ds), .rw_i(!io_write),
        .ad_i(io_wdata), .ad_o(rtc_rdata), .ad_oe_o(rtc_oe),
        .reset_n_i(1'b1), .ps_i(1'b1), .irq_n_o(rtc_irq_n), .sqw_o(rtc_sqw),
        .dbg_addr_i(6'h00), .dbg_data_o(rtc_dbg)
    );
    assign irq8_o = !rtc_irq_n;

    // ---------------------------------------------------------------- CPU
    // reset_i is the power-good reset of the whole board. The 8042's RC line
    // (P20, active low) resets the 80286 only: on sheet 22 it presets the
    // shutdown flip-flop U105, whose output passes through two more
    // flip-flops (U105, U106) to -SHT DWN, and on sheet 1 U94 ORs that with
    // the 82284 RESET at the 80286 RESET pin. The reset is a level that
    // lasts while RC is low plus the flip-flop delay.
    // ASSUMPTION AT7 (see spec): the two-stage synchronizer of the CPU
    // wrapper's RES input stands in for the U105/U106 stages. The same
    // flip-flop also turns an 80286 shutdown cycle into a CPU reset; that
    // path is not wired yet, so a shutdown stops the run.
    logic peack_n_unused;
    /* verilator lint_off PINMISSING */
    intel_80286_native_cpu cpu (
        .clk_i(clk_i), .clk_2x_i(clk_2x_i), .reset_i(reset_i), .res_n_i(rc_n_o && shutdown_reset_n),
        .ready_n_i(cpu_ready_n), .cenl_i(1'b1), .cen_i(1'b1), .cmdly_i(1'b0),
        .hold_i(hold), .intr_i(intr_o), .nmi_i(1'b0), .busy_i(1'b0),
        .error_n_i(1'b1), .pereq_i(1'b0), .peack_n_o(peack_n_unused),
        .data_i(cpu_data), .data_o(data_o), .data_oe_o(data_oe_o),
        .address_o(cpu_address), .address_oe_o(address_oe_o),
        .bhe_n_o(bhe_n_o), .cod_inta_o(cod_inta), .m_io_o(m_io),
        .s1_o(s1), .s0_o(s0), .status_oe_o(status_oe), .hlda_o(hlda_o),
        .cycle_active_o(cycle_active_o), .protocol_error_o(protocol_error_o),
        .completed_bytes_o(completed_bytes_o), .halted_o(halted_o),
        .shutdown_o(shutdown_o), .fault_o(fault_o), .cpu_reset_o(cpu_reset_o)
    );
    intel_80286_at_refresh_path refresh_path (
        .reset_n_i(!reset_i), .sys_clk_i(clk_2x_i), .dma_clk_n_i(dma_clk_n_i),
        .timer_out1_i(timer_out[1]), .dma_request_i(1'b0), .cpu_hlda_i(hlda_o),
        .hold_permit_i(hold_permit_i), .io_ready_i(refresh_ready_i), .cpu_hold_o(hold),
        .refresh_o(refresh_o), .refresh_n_o(refresh_n), .detect_o(detect),
        .refresh_row_o(refresh_row_o), .refresh_row_oe_o(refresh_row_oe_o),
        .refresh_memr_n_o(refresh_memr_n_o), .refresh_memr_oe_o(refresh_memr_oe_o)
    );
    /* verilator lint_on PINMISSING */

    // Sheet 22: U84 decodes the 80286 shutdown cycle (A1, S1 and S0 low with
    // M/-IO high) and clocks flip-flop U105, which resets the processor
    // through the same -SHT DWN net as RC. Only the 80286 is reset. The
    // reset ends when the processor's reset clears its shutdown state.
    assign shutdown_reset_n = !shutdown_o;
    assign inta_cycle_o = inta_tc;

    // ------------------------------------------------- interrupt controllers
    // Two 8259As on sheet 16: master U114 (SP/-EN pulled up) and slave U125
    // (SP/-EN grounded), CAS0-2 wired pin to pin, the slave's INT on the
    // master's IR2 and the master's INT straight to the 80286 INTR pin.
    // Selects come from U123 on sheet 13: -INTR1 CS for 020h-03Fh and
    // -INTR 2 CS for 0A0h-0BFh. A0 of each chip is XA0, so each answers at
    // every address of its block. -INTA comes from the 82288.
    // The model takes a read or write on every clock its strobe is low, so
    // each strobe is one clock, at the end of the bus cycle.
    // Requests: master IR0 = 8254 OUT0 (direct), IR1 = +OPT BUF FULL from the
    // 8042, IR3-IR7 = I/O channel IRQ 3-7; slave IR0 = IRQ 8 from the
    // MC146818, IR1-IR4 = IRQ 9-12, IR5 = IRQ 13 from the coprocessor logic,
    // IR6-IR7 = IRQ 14-15.
    // ASSUMPTION AT16 (see spec): the I/O channel request lines have no
    // pull-ups on the schematic; with no adapter they are taken as inactive.
    logic pic1_sel, pic2_sel, pic1_valid, pic2_valid, pic1_oe, pic2_oe, pic1_int, pic2_int;
    logic [7:0] pic1_rdata, pic2_rdata;
    logic [2:0] pic_cas, pic_cas_oe;
    logic inta_cycle, inta_tc, inta_waited, inta_n;
    assign pic1_sel = io_req && io_addr[9:5] == 5'b00001;
    assign pic2_sel = io_req && io_addr[9:5] == 5'b00101;
    assign pic1_valid = pic1_sel && io_accept && !io_write;
    assign pic2_valid = pic2_sel && io_accept && !io_write;

    // Interrupt acknowledge: two bus cycles with status 0000. -INTA is low
    // for the command phase of each.
    // ASSUMPTION AT13 (see spec): each acknowledge cycle gets one wait state.
    // The 8259 model samples -INTA on the clock, so it needs one clock to
    // put the vector on the bus; the real 8259A answers inside the cycle.
    always_ff @(posedge clk_i) begin
        if (cpu_reset_o) inta_cycle <= 1'b0;
        else if (status_oe) inta_cycle <= status == 4'h0;
        inta_waited <= inta_tc;
    end
    assign inta_tc = address_oe_o && !status_oe && inta_cycle;
    assign inta_n = !inta_tc;
    assign cpu_ready_n = ready_n_i || (inta_tc && !inta_waited) || (word_io && conv != 2'd2);
    assign intr_o = pic1_int;

    /* verilator lint_off PINCONNECTEMPTY */
    intel_8259 pic1 (
        .clk(clk_i), .rst_n(!reset_i),
        .cs_n(!pic1_sel), .rd_n(!pic1_valid), .wr_n(!(pic1_sel && io_write && io_accept)),
        .a0(io_addr[0]), .data_i(io_wdata), .data_o(pic1_rdata), .data_oe(pic1_oe),
        .ir({chan_irq_i[7:3], pic2_int, kbc_obf_o, timer_out[0]}),
        .int_o(pic1_int), .inta_n(inta_n),
        .cas_i(3'b000), .cas_o(pic_cas), .cas_oe(pic_cas_oe),
        .sp_n_i(1'b1), .en_n_o(), .en_n_oe()
    );
    intel_8259 pic2 (
        .clk(clk_i), .rst_n(!reset_i),
        .cs_n(!pic2_sel), .rd_n(!pic2_valid), .wr_n(!(pic2_sel && io_write && io_accept)),
        .a0(io_addr[0]), .data_i(io_wdata), .data_o(pic2_rdata), .data_oe(pic2_oe),
        .ir({chan_irq_i[15:14], irq13, chan_irq_i[12:9], irq8_o}),
        .int_o(pic2_int), .inta_n(inta_n),
        .cas_i(pic_cas & pic_cas_oe), .cas_o(), .cas_oe(),
        .sp_n_i(1'b0), .en_n_o(), .en_n_oe()
    );
    /* verilator lint_on PINCONNECTEMPTY */

    // ---------------------------------------------- math coprocessor ports
    // Sheet 3: U123 selects 0E0h-0FFh (-CS287) and PAL U130 decodes it with
    // XA3, XA0 and -XIOW into the busy-latch clear (port F0h), +RESET 287
    // (port F1h), -NPCS, -BUSY 286 and IRQ 13. Only writes reach the PAL.
    // No 80287 is fitted: -BUSY and -ERROR are pulled up, IRQ 13 stays
    // inactive, and both writes have no effect.
    // ASSUMPTION AT17 (see spec): the PAL equations are not published; the
    // writes are decoded at F0h and F1h only.
    logic copro_sel, irq13;
    assign copro_sel = io_req && io_write &&
                       (io_addr[9:0] == 10'h0f0 || io_addr[9:0] == 10'h0f1);
    assign irq13 = 1'b0;

    // ------------------------------------------------- timer and port 61h
    intel_80286_at_timer timer (
        .clk(clk_i), .rst_n(!reset_i), .io_req_i(io_req), .io_ready_i(io_accept),
        .io_write_i(io_write), .io_addr_i(io_addr), .io_wdata_i(io_wdata),
        .port61_bit0_i(port61_control[0]), .counter_clk_i(timer_clk_i),
        .selected_o(timer_sel), .rdata_valid_o(timer_valid),
        .rdata_o(timer_rdata), .timer_out_o(timer_out)
    );
    intel_80286_at_port61 port61 (
        .clk(clk_i), .reset_n(!reset_i), .io_req_i(io_req), .io_ready_i(io_accept),
        .io_write_i(io_write), .io_addr_i(io_addr), .io_wdata_i(io_wdata[3:0]),
        .refresh_detect_i(detect), .timer2_out_i(timer_out[2]),
        .iochck_i(1'b0), .pck_i(1'b0), .selected_o(port61_sel),
        .rdata_valid_o(port61_valid), .rdata_o(port61_rdata), .control_o(port61_control)
    );

    // ------------------------------------------------------ DMA and pages
    intel_80286_at_dma dma (
        .clk(clk_i), .rst_n(!reset_i), .io_req_i(io_req), .io_ready_i(io_accept),
        .io_write_i(io_write), .io_addr_i(io_addr), .io_wdata_i(io_wdata),
        .selected_o(dma_sel), .controller2_o(dma_ctrl2),
        .rdata_valid_o(dma_valid), .rdata_o(dma_rdata)
    );
    intel_80286_at_page page (
        .clk(clk_i), .rst_n(!reset_i), .io_req_i(io_req), .io_ready_i(io_accept),
        .io_write_i(io_write), .io_addr_i(io_addr), .io_wdata_i(io_wdata),
        .map_index_i(page_map_index_o), .selected_o(page_sel),
        .rdata_valid_o(page_valid), .rdata_o(page_rdata), .map_data_o(map_data)
    );
    // ASSUMPTION AT4: no DMA channel requests service yet, so every DACK
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

    // ------------------------------------------- 8042 keyboard controller
    // Sheet 17, U126. Host side: D0-D7 = XD0-XD7, A0 = XA2, -RD = -XIOR,
    // -WR = -XIOW, -CS = -8042 CS. Decode: sheet 13 U123 (74ALS138) makes
    // -PPI CS for 060h-07Fh from XA5-XA9; sheet 18 U115 (74S288 PROM) splits
    // it using XA4 and XA0 into -8042 CS, the port B strobes and -NMI CS.
    // Address bits above XA9 are not decoded on the system board.
    // ASSUMPTION AT8 (see spec): the PROM contents are not published; the
    // 8042 is taken to answer at every even address 060h-06Eh (XA4 = 0,
    // XA0 = 0), which contains its documented ports 60h and 64h, and port B
    // at the odd ones. With A0 = XA2, 60h is data and 64h command/status.
    // The read and write strobes last for the whole I/O cycle; the 8042 acts
    // on their trailing edge.
    logic [7:0] kbc_p1_o, kbc_p1_i, kbc_p2_o;
    logic kbc_ce, kbc_oe, kbc_t0, kbc_t1;
    logic [$clog2(KBC_CYCLE_CLKS)-1:0] kbc_div;
    assign kbc_sel = io_req && io_addr[9:4] == 6'h06 && !io_addr[0];
    assign kbc_valid = kbc_sel && io_accept && !io_write;

    always_ff @(posedge clk_i) begin
        if (reset_i) kbc_div <= '0;
        else if (kbc_ce) kbc_div <= '0;
        else kbc_div <= kbc_div + 1'b1;
    end
    assign kbc_ce = kbc_div == $bits(kbc_div)'(KBC_CYCLE_CLKS - 1);

    // Port 1 (input port). P10-P13 are not connected and read 1 through the
    // 8042's internal pull-ups. P14 = -RAM SEL / J18 (10K pull-up RN4, sheet
    // 5), P15 = manufacturing jumper pad, P16 = SW1 to ground, P17 = +KBD
    // INH from J20. P15-P17 have no external pull-up.
    assign kbc_p1_i = kbc_p1_o & {kbd_unlocked_i, display_mono_i, !mfg_jumper_i, ram_512k_i, 4'hf};

    // Keyboard lines. P26 drives the clock line through an inverter and an
    // open-collector buffer; P27 drives the data line through an
    // open-collector buffer. T0 reads the clock line, T1 the data line.
    // Sheet 17: P26 -> U120 (74ALS00 as inverter) -> U116 (7407) -> KBD CLK;
    // P27 -> U116 (7407) -> KBD DATA; 10K pull-ups RN5 on both lines.
    assign kbd_clk_o  = !kbc_p2_o[6] && kbd_clk_i;
    assign kbd_data_o = kbc_p2_o[7] && kbd_data_i;
    assign kbc_t0 = kbd_clk_o;
    assign kbc_t1 = kbd_data_o;

    // Port 2 (output port): P20 = RC, P21 = A20 GATE, P24 = +OPT BUF FULL
    // (sheet 16: straight to master 8259A IR1). P22, P23, P25 unconnected.
    assign rc_n_o     = kbc_p2_o[0];
    assign a20_gate_o = kbc_p2_o[1];
    assign kbc_obf_o  = kbc_p2_o[4];

    /* verilator lint_off PINCONNECTEMPTY */
    intel_8042 #(.ROM_FILE(KBC_ROM_FILE)) kbc (
        .clk(clk_i), .rst_n(!reset_i), .ce_i(kbc_ce),
        .cs_n_i(!kbc_sel), .rd_n_i(!(kbc_sel && !io_write)), .wr_n_i(!(kbc_sel && io_write)),
        .a0_i(io_addr[2]), .d_i(io_wdata), .d_o(kbc_rdata), .d_oe_o(kbc_oe),
        .p1_o(kbc_p1_o), .p1_i(kbc_p1_i), .p2_o(kbc_p2_o), .p2_i(kbc_p2_o),
        .t0_i(kbc_t0), .t1_i(kbc_t1),
        .retire_o(), .retire_pc_o(), .retire_op_o(), .retire_kind_o(),
        .illegal_o(kbc_illegal_o)
    );
    /* verilator lint_on PINCONNECTEMPTY */

    logic unused;
    assign unused = ^{dma_ctrl2, port61_control[3:1], kbc_oe, peack_n_unused, pic1_oe, pic2_oe,
                      chan_irq_i[13], chan_irq_i[8], chan_irq_i[2:0],
                      rtc_oe, rtc_sqw, rtc_dbg};
endmodule

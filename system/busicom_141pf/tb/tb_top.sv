`timescale 1ns/1ps
// ============================================================================
// BUSICOM 141-PF virtual platform top.
//
// Clock/reset generation, printer-drum pacing (spec 3.3/4.2: the CPU TEST
// pin toggles every drum half-spin and the drum-index pulse fires through
// ROM2 bit 0), and the front-panel host connection.
//
// The testbench is deliberately FULLY TIME-DRIVEN (# delays only): xezim
// 0.10.3 mis-schedules testbench processes that resume on @(posedge clk)
// once a DPI import is in the build, so no testbench process waits on the
// clock. One machine cycle is 8 clocks = 80ns; machine-cycle boundaries
// land at t = 305ns + 80ns*k.
//
// xezim 0.10.3 DPI calls also cost ~0.2ms wall each, so the host bridge is
// NOT called per cycle: the board latches one-shot print/advance events in
// the clock domain and the host polls them once per PANEL_TICK_CYCLES
// machine cycles (~16ms of machine time, the reference host cadence).
//
// Two builds:
//   headless (default): no host. Keyboard mask reads 0; the self-check
//     verifies the firmware is alive by watching the keyboard scan one-hot
//     sweep all 10 matrix rows, then finishes.
//   +define+SYSTEM_DPI: panel bridge over DPI-C (keys in, printer/lamp
//     events out), with optional real-time pacing in the bridge.
// ============================================================================
module tb_top;

    localparam int CYCLES_PER_SPIN = 1481; // machine cycles per drum half-spin
    localparam int SPINS_PER_INDEX = 26;   // index pulse at spin counter 26
    localparam int CYCLE_NS = 80;
    localparam int PANEL_TICK_CYCLES = 1481;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic clr_n = 1'b0;
    logic test_i = 1'b0;
    logic panel_tick = 1'b0;

    // front panel inputs (host bridge or headless ties)
    logic [31:0] keys_mask = 32'h0;
    logic [3:0]  precision = 4'h0;
    logic [3:0]  rounding  = 4'h0;
    logic        paper_btn = 1'b0;
    logic [3:0]  drum_pos = 4'h0;

    // front panel outputs
    logic        hammer_evt;
    logic [23:0] hammer_data; // {drum_pos[3:0], shifter word[19:0]}
    logic        advance_evt;
    logic        red;
    logic [2:0]  lamps;       // {negative, overflow, memory}
    logic        key_seen;
    logic [9:0]  kb_scan;

    busicom_141pf dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .clr_n          (clr_n),
        .test_i         (test_i),
        .panel_tick_i   (panel_tick),
        .keys_mask_i    (keys_mask),
        .precision_i    (precision),
        .rounding_i     (rounding),
        .paper_btn_i    (paper_btn),
        .hammer_evt_o   (hammer_evt),
        .hammer_data_o  (hammer_data),
        .advance_evt_o  (advance_evt),
        .red_o          (red),
        .lamps_o        (lamps),
        .drum_pos_i     (drum_pos),
        .key_seen_o     (key_seen),
        .kb_scan_o      (kb_scan)
    );

    // 8 clocks per machine cycle (plain always: xezim recognizes this
    // form as a clock generator and takes its fast path)
    always #5 clk = ~clk;

    // power-on: RESET released at 95ns, CL (I/O latch clear) at 295ns
    initial begin
        #95  rst_n = 1'b1;
        #200 clr_n = 1'b1;
    end

    // ------------------------------------------------------------------------
    // Machine-cycle loop: counters and drum pacing.
    // +spin=N shrinks the half-spin length for faster-than-real-time tests;
    // all drum timings scale together, so firmware behaviour is unchanged.
    // ------------------------------------------------------------------------
    longint mcycle = 0;
    int drum_cnt = 0;
    int spin_cnt = 0;
    int spin_cycles = CYCLES_PER_SPIN;

    initial begin
        if (!$value$plusargs("spin=%d", spin_cycles))
            spin_cycles = CYCLES_PER_SPIN;
        #305;
        forever begin
            #CYCLE_NS;
            mcycle = mcycle + 1;

            // ---- drum half-spin tick (reference drum mechanics) ---------
            if (drum_cnt >= spin_cycles - 1) begin
                drum_cnt = 0;
                if (spin_cnt % 2 == 0) begin
                    test_i <= 1'b1;
                    if (spin_cnt == SPINS_PER_INDEX) begin
                        // index: character 0 is in the print position
                        drum_idx <= 1'b1;
                        drum_pos <= 4'd0;
                        spin_cnt = 1;
                    end else begin
                        drum_idx <= 1'b0;
                        drum_pos <= (drum_pos == 4'd12) ? 4'd0
                                                        : drum_pos + 4'd1;
                        spin_cnt = spin_cnt + 1;
                    end
                end else begin
                    test_i <= 1'b0;
                    spin_cnt = spin_cnt + 1;
                end
            end else begin
                drum_cnt = drum_cnt + 1;
            end
        end
    end

    logic drum_idx = 1'b0;

    // ------------------------------------------------------------------------
    // Headless self-check: firmware aliveness = keyboard scan sweeps all rows
    // ------------------------------------------------------------------------
    `ifndef SYSTEM_DPI
    logic [9:0] seen = 10'h0;
    int printer_events = 0;
    logic [3:0] ram0_prev = 4'h0;
    int check_cycles = 600000;

    initial begin
        if (!$value$plusargs("cycles=%d", check_cycles))
            check_cycles = 600000;
        #(check_cycles * CYCLE_NS + 400);
        if (seen == 10'h3FF)
            $display("SYSTEM SELF-TEST PASS: scan rows swept %010b, printer events %0d after %0d machine cycles",
                     seen, printer_events, mcycle);
        else
            $display("SYSTEM SELF-TEST FAIL: scan rows seen %010b (missing %010b) after %0d machine cycles, printer events %0d",
                     seen, ~seen & 10'h3FF, mcycle, printer_events);
        $finish;
    end

    // per-cycle sampler (headless diagnostics)
    initial begin
        #305;
        forever begin
            #CYCLE_NS;
            if (kb_scan != '0 && (kb_scan & (kb_scan - 1)) == '0)
                seen <= seen | kb_scan;
            if (dut.ram0_port != ram0_prev) begin
                ram0_prev <= dut.ram0_port;
                if (dut.ram0_port != 4'h0)
                    printer_events = printer_events + 1;
            end
        end
    end
    `endif

    // ------------------------------------------------------------------------
    // Front-panel host tick (bridge build): deliver events, fetch inputs
    // ------------------------------------------------------------------------
    `ifdef SYSTEM_DPI
    import "DPI-C" function int dpi_panel_keys();
    import "DPI-C" function int dpi_panel_ctrl(int evflags, int hammer24,
                                               int lamps);

    int dpi_keys;
    int dpi_ctrl;
    int evflags;
    int tick_count = 0;
    int key_hold = 0;

    initial begin
        key_hold = $test$plusargs("keyhold") ? 32'h04000000 : 32'h0;
    end

    initial begin
        #305;
        forever begin
            repeat (spin_cycles) #(CYCLE_NS); // one tick per drum half-spin
            tick_count = tick_count + 1;
            dpi_keys = dpi_panel_keys();
            dpi_keys = dpi_panel_keys();
            evflags  = {23'h0, key_seen, drum_pos, red, advance_evt,
                        hammer_evt};
            dpi_ctrl = dpi_panel_ctrl(evflags, {8'h0, hammer_data},
                                      {29'h0, lamps});
            keys_mask    <= key_hold ? key_hold : dpi_keys;
            precision    <= dpi_ctrl[3:0];
            rounding     <= dpi_ctrl[7:4];
            paper_btn    <= dpi_ctrl[8];
            panel_tick   <= ~panel_tick; // ack: board drops delivered events
            `ifdef DEBUG_TRACE
            if (dpi_keys != 0 || hammer_evt || advance_evt || lamps != 0)
                $display("[%0t] TICK keys=%08h h=%b a=%b red=%b lamp=%b dpos=%0d iosel=%0d rdr=%b wrr=%b",
                         $time, dpi_keys, hammer_evt, advance_evt, red, lamps,
                         drum_pos, dut.u_rom1.u_4001.io_sel_q,
                         dut.u_rom1.u_4001.s_rdr, dut.u_rom1.u_4001.s_wrr);
            if (tick_count % 8 == 0)
                $display("[%0t] RAM0 r0=%h%h%h%h %h%h%h%h %h%h%h%h %h%h%h%h st=%h%h%h%h | r1=%h%h%h%h %h%h%h%h %h%h%h%h %h%h%h%h",
                         $time,
                         dut.u_ram0.main_mem[0], dut.u_ram0.main_mem[1],
                         dut.u_ram0.main_mem[2], dut.u_ram0.main_mem[3],
                         dut.u_ram0.main_mem[4], dut.u_ram0.main_mem[5],
                         dut.u_ram0.main_mem[6], dut.u_ram0.main_mem[7],
                         dut.u_ram0.main_mem[8], dut.u_ram0.main_mem[9],
                         dut.u_ram0.main_mem[10], dut.u_ram0.main_mem[11],
                         dut.u_ram0.main_mem[12], dut.u_ram0.main_mem[13],
                         dut.u_ram0.main_mem[14], dut.u_ram0.main_mem[15],
                         dut.u_ram0.stat_mem[0], dut.u_ram0.stat_mem[1],
                         dut.u_ram0.stat_mem[2], dut.u_ram0.stat_mem[3],
                         dut.u_ram0.main_mem[16], dut.u_ram0.main_mem[17],
                         dut.u_ram0.main_mem[18], dut.u_ram0.main_mem[19],
                         dut.u_ram0.main_mem[20], dut.u_ram0.main_mem[21],
                         dut.u_ram0.main_mem[22], dut.u_ram0.main_mem[23],
                         dut.u_ram0.main_mem[24], dut.u_ram0.main_mem[25],
                         dut.u_ram0.main_mem[26], dut.u_ram0.main_mem[27],
                         dut.u_ram0.main_mem[28], dut.u_ram0.main_mem[29],
                         dut.u_ram0.main_mem[30], dut.u_ram0.main_mem[31]);
            if (tick_count % 8 == 4)
                $display("[%0t] RAM1 r0=%h%h%h%h %h%h%h%h %h%h%h%h %h%h%h%h st=%h%h%h%h | RAM0 r2=%h%h%h%h %h%h%h%h %h%h%h%h %h%h%h%h",
                         $time,
                         dut.u_ram1.main_mem[0], dut.u_ram1.main_mem[1],
                         dut.u_ram1.main_mem[2], dut.u_ram1.main_mem[3],
                         dut.u_ram1.main_mem[4], dut.u_ram1.main_mem[5],
                         dut.u_ram1.main_mem[6], dut.u_ram1.main_mem[7],
                         dut.u_ram1.main_mem[8], dut.u_ram1.main_mem[9],
                         dut.u_ram1.main_mem[10], dut.u_ram1.main_mem[11],
                         dut.u_ram1.main_mem[12], dut.u_ram1.main_mem[13],
                         dut.u_ram1.main_mem[14], dut.u_ram1.main_mem[15],
                         dut.u_ram1.stat_mem[0], dut.u_ram1.stat_mem[1],
                         dut.u_ram1.stat_mem[2], dut.u_ram1.stat_mem[3],
                         dut.u_ram0.main_mem[32], dut.u_ram0.main_mem[33],
                         dut.u_ram0.main_mem[34], dut.u_ram0.main_mem[35],
                         dut.u_ram0.main_mem[36], dut.u_ram0.main_mem[37],
                         dut.u_ram0.main_mem[38], dut.u_ram0.main_mem[39],
                         dut.u_ram0.main_mem[40], dut.u_ram0.main_mem[41],
                         dut.u_ram0.main_mem[42], dut.u_ram0.main_mem[43],
                         dut.u_ram0.main_mem[44], dut.u_ram0.main_mem[45],
                         dut.u_ram0.main_mem[46], dut.u_ram0.main_mem[47]);
            `endif
        end
    end
    `endif

    // ------------------------------------------------------------------------
    // Debug heartbeat (any build with +define+DEBUG_TRACE)
    // ------------------------------------------------------------------------
    `ifdef DEBUG_TRACE
    initial begin
        forever begin
            #40000000; // every 500k machine cycles
            $display("[%0t] HB mcycle=%0d scan=%b kb=%b prec=%0d round=%0d test=%b lamp=%b hammer=%b adv=%b red=%b",
                     $time, mcycle, kb_scan, keys_mask, precision, rounding,
                     test_i, lamps, hammer_evt, advance_evt, red);
        end
    end
    `endif

endmodule

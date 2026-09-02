`timescale 1ns/1ps
// ============================================================================
// BUSICOM 141-PF virtual platform top.
//
// Clock/reset generation, printer-drum pacing (spec 3.3/4.2: the CPU TEST
// pin toggles every drum half-spin and the drum-index pulse fires through
// ROM2 bit 0), and the front-panel host connection.
//
// Two builds:
//   headless (default): no host. Keyboard nibble reads 0; the self-check
//     verifies the firmware is alive by watching the keyboard scan one-hot
//     sweep all 10 matrix rows, then finishes.
//   +define+SYSTEM_DPI: one DPI-C call per machine cycle feeds the panel
//     bridge (keys in, printer/lamp state out) and paces the simulation to
//     real time when the bridge asks for it (see host/dpi/panel_bridge.c).
// ============================================================================
module tb_top;

    localparam int CYCLES_PER_SPIN = 1481; // machine cycles per drum half-spin
    localparam int SPINS_PER_INDEX = 27;   // index pulse when spin counter hits 26

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic clr_n = 1'b0;
    logic test_i = 1'b0;
    logic [3:0] kb_col = 4'h0;
    logic [3:0] rom2_pins = 4'h0;

    logic [3:0] rom0_port, ram0_port, ram1_port;
    logic [9:0] kb_scan;
    logic [19:0] printer_bits;

    busicom_141pf dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .clr_n          (clr_n),
        .test_i         (test_i),
        .kb_col_i       (kb_col),
        .rom2_pin_i     (rom2_pins),
        .rom0_port_o    (rom0_port),
        .ram0_port_o    (ram0_port),
        .ram1_port_o    (ram1_port),
        .kb_scan_o      (kb_scan),
        .printer_bits_o (printer_bits)
    );

    // 8 clocks per machine cycle
    always #5 clk = ~clk;

    // ------------------------------------------------------------------------
    // Machine-cycle counter, drum pacing, host tick
    // ------------------------------------------------------------------------
    int phase_cnt = 0;
    longint mcycle = 0;
    int drum_cnt = 0;
    int spin_cnt = 0;
    logic drum_idx = 1'b0;

    `ifdef SYSTEM_DPI
    // Returns {paper_btn, 3'b000} in [7:4] (ROM2 bit3), keyboard nibble in
    // [3:0]. The C side also paces real time, tracks the drum position from
    // the TEST pin, and consumes the printer/lamp state passed in.
    import "DPI-C" function int dpi_cycle(
        input int scan10, input int ram0, input int ram1, input int shift20,
        input int test);
    `endif

    always @(posedge clk) begin
        if (!rst_n) begin
            phase_cnt <= 0;
            mcycle    <= 0;
            drum_cnt  <= 0;
            spin_cnt  <= 0;
            test_i    <= 1'b0;
            drum_idx  <= 1'b0;
        end else begin
            if (phase_cnt == 7) begin
                phase_cnt <= 0;
                mcycle    <= mcycle + 1;

                // ---- drum half-spin tick --------------------------------
                if (drum_cnt == CYCLES_PER_SPIN - 1) begin
                    drum_cnt <= 0;
                    if (spin_cnt % 2 == 0) begin
                        test_i <= 1'b1;
                        // index pulse (stays set through the odd half-spin,
                        // matching the drum mechanics reference)
                        drum_idx <= (spin_cnt == SPINS_PER_INDEX - 1);
                        spin_cnt <= (spin_cnt == SPINS_PER_INDEX - 1) ? 0
                                                                       : spin_cnt + 1;
                    end else begin
                        test_i <= 1'b0;
                        spin_cnt <= spin_cnt + 1;
                    end
                end else begin
                    drum_cnt <= drum_cnt + 1;
                end

                // ---- front-panel host ------------------------------------
                `ifdef SYSTEM_DPI
                begin
                    int host;
                    host    = dpi_cycle({6'h0, kb_scan}, {4'h0, ram0_port},
                                        {4'h0, ram1_port},
                                        {12'h0, printer_bits},
                                        {31'h0, test_i});
                    kb_col    <= host[3:0];
                    rom2_pins <= {host[4], 3'b000, drum_idx};
                end
                `endif
            end else begin
                phase_cnt <= phase_cnt + 1;
            end
        end
    end

    // ------------------------------------------------------------------------
    // Headless self-check: firmware aliveness = keyboard scan sweeps all rows
    // ------------------------------------------------------------------------
    `ifndef SYSTEM_DPI
    logic [9:0] seen = 10'h0;
    int printer_events = 0;
    logic [3:0] ram0_prev = 4'h0;
    int check_cycles = 600000;

    always @(posedge clk) begin
        if (rst_n) begin
            if (ram0_port != ram0_prev) begin
                ram0_prev <= ram0_port;
                if (ram0_port != 4'h0) printer_events <= printer_events + 1;
            end
        end
    end

    always @(posedge clk) begin
        if (rst_n && kb_scan != '0 && (kb_scan & (kb_scan - 1)) == '0) begin
            seen <= seen | kb_scan;
        end
    end

    initial begin
        if (!$value$plusargs("cycles=%d", check_cycles)) begin
            check_cycles = 600000;
        end
        // power-on: RESET, then a CL pulse to clear the 4001 I/O latches
        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (20) @(posedge clk);
        clr_n = 1'b1;

        wait (mcycle >= check_cycles);
        if (seen == 10'h3FF) begin
            $display("SYSTEM SELF-TEST PASS: scan rows swept %010b, printer events %0d after %0d machine cycles",
                     seen, printer_events, mcycle);
        end else begin
            $display("SYSTEM SELF-TEST FAIL: scan rows seen %010b (missing %010b) after %0d machine cycles, printer events %0d",
                     seen, ~seen & 10'h3FF, mcycle, printer_events);
        end
        $finish;
    end
    `endif

endmodule

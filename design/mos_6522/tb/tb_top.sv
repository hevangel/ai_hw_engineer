`timescale 1ns/1ps
module tb_top;
    logic clk = 0, rst_n = 0, cs1 = 0, cs2_n = 0, rw = 1;
    logic [3:0] addr = 0;
    logic [7:0] data_i = 0, data_o;
    logic data_oe, irq_n;
    logic [7:0] pa_i = 8'hff, pb_i = 8'hff, pa_o, pb_o, pa_oe, pb_oe;
    logic ca1_i = 1, ca2_i = 1, cb1_i = 1, cb2_i = 1;
    logic ca2_o, ca2_oe, cb1_o, cb1_oe, cb2_o, cb2_oe;
    int checks = 0, timer_loads = 0, streams = 0;
    bit quick;
    mos_6522 dut (.*);

    task automatic check(input bit ok, input string message);
        checks++;
        if (!ok) $fatal(1, "%s: t=%0t addr=%x data=%02x", message, $time, addr, data_o);
    endtask
    task automatic tick;
        clk = 1; #1; clk = 0; #1;
    endtask
    task automatic idle(input int n);
        cs1 = 0;
        repeat (n) tick();
    endtask
    task automatic reset_chip;
        cs1 = 0; rst_n = 0; tick(); rst_n = 1;
    endtask
    task automatic wr_reg(input logic [3:0] a, input logic [7:0] value);
        cs1 = 1; rw = 0; addr = a; data_i = value;
        tick(); cs1 = 0; rw = 1;
    endtask
    task automatic expect_reg(input logic [3:0] a, input logic [7:0] expected);
        // Combinational observation without transfer/acknowledgment.
        addr = a; #1;
        check(data_o === expected, "register observation");
    endtask
    task automatic rd_reg(input logic [3:0] a, input logic [7:0] expected);
        cs1 = 1; rw = 1; addr = a; clk = 1; #1;
        check(data_oe && data_o === expected, "read transfer");
        clk = 0; #1; check(!data_oe, "low-phase bus release"); cs1 = 0;
    endtask
    task automatic expect_flags(input logic [6:0] expected);
        logic [6:0] enables;
        addr = 14; #1; enables = data_o[6:0];
        expect_reg(13, {|(expected & enables), expected});
        check(irq_n == !(|(expected & enables)), "IRQ reduction");
    endtask
    task automatic clear_flags;
        wr_reg(13, 8'h7f);
    endtask

    task automatic deadline_case(input int timer, input int n, input bit continuous);
        int cycles;
        logic [15:0] expected;
        reset_chip();
        wr_reg(11, continuous ? 8'hc0 : 8'h80);
        wr_reg(14, timer == 1 ? 8'hc0 : 8'ha0);
        wr_reg(timer == 1 ? 4'h4 : 4'h8, 8'(n));
        wr_reg(timer == 1 ? 4'h5 : 4'h9, 8'(n >> 8));
        cycles = n+2;
        for (int e = 0; e <= cycles; e++) begin
            expected = e < 2 ? 16'(n) : 16'(n-e+1);
            expect_reg(timer == 1 ? 4'h4 : 4'h8, expected[7:0]);
            expect_reg(timer == 1 ? 4'h5 : 4'h9, expected[15:8]);
            check(irq_n == (e < cycles), "exact timer deadline");
            if (timer == 1) check(pb_o[7] == (e == cycles), "PB7 one-shot pulse");
            if (e != cycles) idle(1);
        end
        clear_flags();
        if (!continuous) begin
            idle(65540); // At least one more full 16-bit wrap must not re-IRQ.
            expect_flags(0);
        end else begin
            // Clear consumed one tick: next expiry is now N+1 clocks away.
            idle(n);
            check(irq_n, "free-run before next expiry");
            idle(1); check(!irq_n && !pb_o[7], "free-run period and PB7 toggle");
        end
    endtask

    task automatic serial_case(input int mode, input logic [7:0] pattern, input int divisor);
        int bits_seen, guard, previous_clock, interval, last_edge, cycle_no;
        logic input_bit;
        logic [7:0] shifted;
        reset_chip();
        wr_reg(11, 8'(mode << 2));
        wr_reg(8, 8'(divisor)); wr_reg(9, 8'h01);
        wr_reg(14, 8'h84);
        check(cb1_oe == (mode != 3 && mode != 7), "serial CB1 direction");
        check(cb2_oe == (mode >= 4), "serial CB2 direction");
        cb1_i = 1;
        wr_reg(10, mode >= 4 ? pattern : 8'h00);
        bits_seen = 0; guard = 0; interval = divisor+2;
        last_edge = -1; cycle_no = 0; shifted = 0;
        previous_clock = int'(cb1_o);
        while (bits_seen < (mode == 3 || mode == 4 || mode == 7 ? 16 : 8)) begin
            input_bit = pattern[7 - (bits_seen % 8)];
            cb2_i = input_bit;
            if (mode == 3 || mode == 7) cb1_i = !cb1_i;
            idle(1); cycle_no++;
            if (mode == 3) begin
                if (cb1_i) begin
                    shifted = {shifted[6:0], input_bit}; bits_seen++;
                end
            end else if (mode == 7) begin
                if (!cb1_i) begin
                    check(cb2_o === pattern[7-(bits_seen%8)], "external MSB-first output");
                    bits_seen++;
                end
            end else if (int'(cb1_o) != previous_clock) begin
                if (last_edge >= 0)
                    check(cycle_no-last_edge == (mode == 2 || mode == 6 ? 1 : interval),
                          "serial output clock divider");
                last_edge = cycle_no;
                if (mode < 4 && cb1_o) begin
                    shifted = {shifted[6:0], input_bit}; bits_seen++;
                end else if (mode >= 4 && !cb1_o) begin
                    check(cb2_o === pattern[7-(bits_seen%8)], "internal MSB-first output");
                    bits_seen++;
                end
                previous_clock = int'(cb1_o);
            end
            guard++;
            check(guard < 40*(divisor+2)+100, "serial progress watchdog");
        end
        if (mode == 4) begin
            addr = 13; #1; check(!data_o[2], "continuous SR suppresses interrupts");
        end else begin
            idle(mode == 3 || mode == 7 ? 0 : interval+2);
            addr = 13; #1; check(data_o[2] && !irq_n, "SR completion interrupt");
            if (mode < 4) expect_reg(10, shifted);
            else expect_reg(10, pattern);
        end
        streams++;
    endtask

    initial begin
        quick = $test$plusargs("quick");
        reset_chip();
        expect_reg(14, 8'h80); expect_flags(0);
        check(pa_oe == 0 && pb_oe == 0 && !ca2_oe && !cb2_oe && !cb1_oe, "reset I/O directions");
        // All direction masks; deliberately conflict external pins and latches.
        wr_reg(1, 8'ha5); wr_reg(0, 8'h69); pa_i = 8'h3c; pb_i = 8'h96;
        for (int mask = 0; mask < 256; mask++) begin
            wr_reg(3, 8'(mask)); wr_reg(2, 8'(255-mask));
            expect_reg(3, 8'(mask)); expect_reg(2, 8'(255-mask));
            expect_reg(1, 8'h3c); expect_reg(15, 8'h3c);
            expect_reg(0, (8'h69 & 8'(255-mask)) | (8'h96 & 8'(mask)));
            check(pa_o == 8'ha5 && pa_oe == 8'(mask), "PA direction and output");
            check(pb_o == 8'h69 && pb_oe == 8'(255-mask), "PB direction and output");
        end
        // IER set/clear is selective; data bit 7 is a command, not stored.
        for (int mask = 0; mask < 128; mask++) begin
            wr_reg(14, 8'h7f); wr_reg(14, 8'h80 | 8'(mask));
            expect_reg(14, 8'h80 | 8'(mask));
            wr_reg(14, 8'(mask)); expect_reg(14, 8'h80);
        end
        // All PCR control words: output ownership and constant modes.
        for (int control = 0; control < 256; control++) begin
            wr_reg(12, 8'(control)); expect_reg(12, 8'(control));
            check(ca2_oe == ((control & 8) != 0), "CA2 PCR direction");
            check(cb2_oe == ((control & 128) != 0), "CB2 PCR direction");
            if ((control & 12) == 12) check(ca2_o == ((control & 2) != 0), "manual CA2");
            if ((control & 192) == 192) check(cb2_o == ((control & 32) != 0), "manual CB2");
        end
        // All four input interrupt flags, selective enable and no-handshake ORA.
        ca1_i = 1; ca2_i = 1; cb1_i = 1; cb2_i = 1; reset_chip();
        wr_reg(14, 8'h9b);
        ca1_i = 0; ca2_i = 0; cb1_i = 0; cb2_i = 0; idle(1);
        expect_flags(7'h1b); rd_reg(15, pa_i); expect_flags(7'h1b);
        wr_reg(15, 8'h55); expect_flags(7'h1b);
        rd_reg(1, pa_i); expect_flags(7'h18);
        rd_reg(0, pb_i); expect_flags(0);
        // Rising edges also work; independent CA2/CB2 cannot be port-acked.
        ca1_i = 0; ca2_i = 0; cb1_i = 0; cb2_i = 0; reset_chip();
        wr_reg(12, 8'h77); wr_reg(14, 8'h9b);
        ca1_i = 1; ca2_i = 1; cb1_i = 1; cb2_i = 1; idle(1);
        expect_flags(7'h1b);
        rd_reg(1, pa_i); rd_reg(0, pb_i); expect_flags(7'h09);
        wr_reg(13, 8'h01); expect_flags(7'h08);
        wr_reg(14, 8'h08); check(irq_n, "disabling pending IRQ leaves flag latched");
        expect_flags(7'h08); wr_reg(13, 8'h08); expect_flags(0);
        // A newly arriving event survives a same-cycle write-one-to-clear.
        ca1_i = 1; reset_chip(); ca1_i = 0; wr_reg(13, 8'h02);
        expect_flags(7'h02);

        // Input latches capture once and freeze through further edge activity.
        ca1_i = 1; cb1_i = 1; pa_i = 8'h12; pb_i = 8'h34; reset_chip();
        wr_reg(11, 8'h03);
        ca1_i = 0; cb1_i = 0; idle(1); expect_flags(7'h12);
        pa_i = 8'h56; pb_i = 8'h78; idle(1);
        expect_reg(1, 8'h12); expect_reg(0, 8'h34);
        ca1_i = 1; cb1_i = 1; idle(1); ca1_i = 0; cb1_i = 0; idle(1);
        expect_reg(15, 8'h12); expect_reg(0, 8'h34);
        rd_reg(15, 8'h12); expect_flags(7'h12);
        rd_reg(1, 8'h12); expect_reg(1, 8'h56); expect_flags(7'h10);
        rd_reg(0, 8'h34); expect_reg(0, 8'h78); expect_flags(0);
        // PB latch captures output-latch bits as well as actual input bits.
        wr_reg(2, 8'hf0); wr_reg(0, 8'ha5);
        cb1_i = 1; idle(1); cb1_i = 0; idle(1);
        wr_reg(2, 8'h00); expect_reg(0, 8'ha8);

        ca1_i = 1; cb1_i = 1; reset_chip();
        wr_reg(12, 8'h88); // Handshake on both C2 pins.
        check(ca2_o && cb2_o, "idle handshake high");
        wr_reg(1, 8'h11); check(!ca2_o, "PA write handshake");
        wr_reg(15, 8'h22); check(!ca2_o, "no-handshake write leaves CA2");
        ca1_i = 0; idle(1); check(ca2_o, "CA1 releases handshake");
        rd_reg(1, pa_i); check(!ca2_o, "PA read handshake");
        ca1_i = 1; idle(1); ca1_i = 0; idle(1); check(ca2_o, "CA1 second release");
        wr_reg(0, 8'h33); check(!cb2_o, "PB write handshake");
        rd_reg(0, pb_i); check(!cb2_o, "PB read does not drive handshake");
        cb1_i = 0; idle(1); check(cb2_o, "CB1 releases handshake");
        wr_reg(12, 8'haa); wr_reg(1, 8'h44); check(!ca2_o, "CA2 pulse starts");
        idle(1); check(ca2_o, "CA2 pulse one cycle");
        wr_reg(0, 8'h55); check(!cb2_o, "CB2 pulse starts");
        idle(1); check(cb2_o, "CB2 pulse one cycle");

        reset_chip();
        wr_reg(4, 20); wr_reg(5, 0); wr_reg(6, 3); wr_reg(7, 0);
        expect_reg(4, 19); expect_reg(6, 3); // Latch-only write did not reload.
        cs1 = 0; rw = 1; clk = 1; #1; check(!data_oe, "deselected read releases bus");
        cs1 = 1; cs2_n = 1; #1; check(!data_oe, "CS2 high releases bus");
        cs2_n = 0; #1; check(data_oe, "selected high phase drives bus");
        rst_n = 0; #1; check(!data_oe && irq_n, "reset gates bus and IRQ");
        clk = 0; #1; rst_n = 1; cs1 = 0;
        // Every 16-bit load: readback, first hold and decrement, both timers.
        reset_chip();
        for (int n = 0; n < 65536; n++) begin
            if (!quick || n < 256 || (n & 255) == 0 || n == 65535) begin
                wr_reg(4, 8'(n)); wr_reg(5, 8'(n >> 8));
                wr_reg(8, 8'(n)); wr_reg(9, 8'(n >> 8));
                expect_reg(8, 8'(n)); expect_reg(9, 8'(n >> 8));
                idle(1); expect_reg(8, 8'(n)); expect_reg(9, 8'(n >> 8));
                idle(1); expect_reg(8, 8'(n-1)); expect_reg(9, 8'((n-1) >> 8));
                // T1 was loaded two bus clocks earlier and is N-3 now,
                // except N=0/1 where it reloads through FFFF.
                wr_reg(4, 8'(n)); wr_reg(5, 8'(n >> 8));
                expect_reg(4, 8'(n)); expect_reg(5, 8'(n >> 8));
                idle(1); expect_reg(4, 8'(n)); expect_reg(5, 8'(n >> 8));
                idle(1); expect_reg(4, 8'(n-1)); expect_reg(5, 8'((n-1) >> 8));
                timer_loads += 2;
            end
        end
        for (int n = 0; n < 256; n++) begin
            // The equation covers every low-byte deadline for both counters.
            reset_chip(); wr_reg(14, 8'he0);
            wr_reg(4, 8'(n)); wr_reg(5, 0);
            for (int e = 0; e < n+2; e++) begin
                check(irq_n, "T1 byte deadline early"); idle(1);
            end
            check(!irq_n, "T1 byte deadline");
            reset_chip(); wr_reg(14, 8'he0);
            wr_reg(8, 8'(n)); wr_reg(9, 0);
            for (int e = 0; e < n+2; e++) begin
                check(irq_n, "T2 byte deadline early"); idle(1);
            end
            check(!irq_n, "T2 byte deadline");
        end
        deadline_case(1, 0, 1); deadline_case(1, 1, 1); deadline_case(1, 255, 1);
        deadline_case(1, 256, 0); deadline_case(1, 65535, 0);
        deadline_case(2, 0, 0); deadline_case(2, 257, 0); deadline_case(2, 65535, 0);

        // PB6 pulse counting includes low-byte borrow and one-shot suppression.
        for (int n = 0; n < 258; n++) begin
            reset_chip(); pb_i[6] = 1; idle(1); wr_reg(11, 8'h20);
            wr_reg(14, 8'ha0); wr_reg(8, 8'(n)); wr_reg(9, 8'(n >> 8));
            for (int pulse = 0; pulse <= n; pulse++) begin
                check(irq_n, "pulse timer early");
                pb_i[6] = 0; idle(1); pb_i[6] = 1; idle(1);
            end
            check(!irq_n, "pulse timer expiry");
            rd_reg(8, 8'hff); expect_flags(0);
        end

        // Serial byte streams test each bit, all modes and every T2 divisor.
        reset_chip(); wr_reg(10, 8'h5a); idle(20); expect_reg(10, 8'h5a);
        check(!cb1_oe && !cb2_oe, "disabled serial pin ownership");
        for (int value = 0; value < 256; value++) begin
            if (!quick || value == 0 || value == 1 || value == 128 || value == 165 || value == 255) begin
                serial_case(2, 8'(value), 0); serial_case(3, 8'(value), 0);
                serial_case(6, 8'(value), 0); serial_case(7, 8'(value), 0);
            end
        end
        for (int div = 0; div < 256; div++) begin
            if (!quick || div < 3 || div == 255) begin
                serial_case(1, 8'ha5, div); serial_case(4, 8'h96, div);
                serial_case(5, 8'h69, div);
            end
        end
        // T2's high byte borrows while the low byte clocks SR and reloads.
        // Expected sequence derives from elapsed-time/period arithmetic.
        reset_chip(); wr_reg(11, 8'h14); wr_reg(14, 8'ha0);
        wr_reg(8, 3); wr_reg(9, 1); wr_reg(10, 8'ha5);
        for (int e = 0; e <= 100; e++) begin
            logic [7:0] low_expected, high_expected;
            int since, phase;
            if (e <= 3) begin
                low_expected = 8'(3-e); high_expected = 1;
            end else begin
                since = e-4; phase = since % 5;
                high_expected = 8'(-(since/5));
                low_expected = phase == 0 ? 8'hff : 8'(4-phase);
            end
            expect_reg(8, low_expected); expect_reg(9, high_expected);
            check(irq_n == (e < 9), "shared T2 full-counter IRQ deadline");
            if (e > 85) check(cb1_o, "finite SR parks while T2 keeps counting");
            if (e != 100) idle(1);
        end
        // SR read acknowledges and retriggers an internally clocked output.
        reset_chip(); wr_reg(11, 8'h18); wr_reg(14, 8'h84); wr_reg(10, 8'h96);
        idle(18); check(!irq_n, "first output completion");
        rd_reg(10, 8'h96); check(irq_n, "SR read acknowledges");
        idle(18); check(!irq_n, "SR read retriggers");
        $display("MOS 6522 PASS: checks=%0d timer_loads=%0d streams=%0d quick=%0d", checks, timer_loads, streams, quick);
        $finish;
    end
endmodule

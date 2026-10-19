`timescale 1ns/1ps
module tb_top;
    logic clk = 0, rst_n = 0, cs1 = 0, cs2_n = 0, rs = 0, rw = 1;
    logic [6:0] addr = 0;
    logic [7:0] data_i = 0, data_o;
    logic data_oe, irq_n;
    logic [7:0] pa_i = 8'hff, pb_i = 8'hff;
    logic [7:0] pa_o, pb_o, pa_oe, pb_oe;
    int checks = 0, timer_cases = 0;
    bit quick;
    mos_6532 dut (.*);

    task automatic check(input bit ok, input string what);
        checks++;
        if (!ok) $fatal(1, "%s at %0t addr=%02x data=%02x", what, $time, addr, data_o);
    endtask
    task automatic tick;
        clk = 1; #1; clk = 0; #1;
    endtask
    task automatic idle(input int n);
        cs1 = 0;
        repeat (n) tick();
    endtask
    task automatic write_bus(input bit regsel, input logic [6:0] a,
                             input logic [7:0] value);
        cs1 = 1; cs2_n = 0; rs = regsel; addr = a; rw = 0; data_i = value;
        tick(); cs1 = 0; rw = 1;
    endtask
    task automatic read_bus(input bit regsel, input logic [6:0] a,
                            input logic [7:0] expected);
        cs1 = 1; cs2_n = 0; rs = regsel; addr = a; rw = 1;
        clk = 1; #1;
        check(data_oe && data_o === expected, "bus read");
        clk = 0; #1; check(!data_oe, "low phase releases bus"); cs1 = 0;
    endtask
    task automatic flags(input logic [7:0] expected);
        // Inspect without a falling edge: this does not acknowledge either flag.
        cs1 = 0; rs = 1; rw = 1; addr = 7'h05; #1;
        check(data_o === expected, "interrupt flags");
        #1;
    endtask
    task automatic reset_chip;
        rst_n = 0; tick(); rst_n = 1;
    endtask
    task automatic timer_case(input int sel, input int n);
        int p, deadline;
        logic [7:0] expected;
        case (sel)
            0: p = 1;
            1: p = 8;
            2: p = 64;
            default: p = 1024;
        endcase
        reset_chip();
        write_bus(1, 7'h1c + 7'(sel), 8'(n));
        deadline = n*p + 1;
        // A timer read changes state: observe the read mux without selecting it.
        rs = 1; addr = 7'h04;
        for (int elapsed = 0; elapsed <= deadline + 2; elapsed++) begin
            if (elapsed == 0) expected = 8'(n);
            else if (elapsed < deadline) expected = 8'(n - 1 - (elapsed-1)/p);
            else expected = 8'(255 - (elapsed-deadline));
            #1;
            check(data_o === 8'(expected), "timer equation");
            check(irq_n == (elapsed < deadline), "timer exact expiry");
            if (elapsed != deadline+2) idle(1);
        end
        timer_cases++;
    endtask

    initial begin
        quick = $test$plusargs("quick");
        reset_chip();
        check(pa_oe == 0 && pb_oe == 0 && pa_o == 0 && pb_o == 0 && irq_n,
              "reset ports");
        // Complementary memory patterns, with no initialization assumptions.
        for (int pattern = 0; pattern < 2; pattern++) begin
            for (int a = 0; a < 128; a++) write_bus(0, 7'(a), 8'(a ^ (pattern*255)));
            reset_chip();
            for (int a = 0; a < 128; a++) read_bus(0, 7'(a), 8'(a ^ (pattern*255)));
        end
        write_bus(0, 7'h12, 8'ha5);
        cs1 = 0; rs = 0; addr = 7'h12; rw = 0; data_i = 0; tick();
        cs1 = 1; cs2_n = 1; tick(); cs2_n = 0; cs1 = 0;
        read_bus(0, 7'h12, 8'ha5);
        rst_n = 0; cs1 = 1; clk = 1; #1;
        check(!data_oe && irq_n, "reset bus and IRQ gating");
        clk = 0; #1; cs1 = 0; rst_n = 1;
        // PA contention/readback differs from PB output-latch readback.
        pa_i = 8'h3c; pb_i = 8'h96;
        write_bus(1, 0, 8'ha5); write_bus(1, 2, 8'h69);
        for (int d = 0; d < 256; d++) begin
            write_bus(1, 1, 8'(d)); write_bus(1, 3, 8'(255-d));
            read_bus(1, 0, 8'h3c);
            read_bus(1, 2, (8'h69 & 8'(255-d)) | (8'h96 & 8'(d)));
            check(pa_o == 8'ha5 && pa_oe == 8'(d), "PA output and DDR");
            check(pb_o == 8'h69 && pb_oe == 8'(255-d), "PB output and DDR");
        end
        write_bus(1, 1, 8'h81); write_bus(1, 3, 8'h42);
        for (int a = 0; a < 128; a++) begin
            if ((a & 4) == 0) begin
                case (a & 3)
                    0: read_bus(1, 7'(a), 8'h3c);
                    1: read_bus(1, 7'(a), 8'h81);
                    2: read_bus(1, 7'(a), (8'h69 & 8'h42) | (8'h96 & 8'hbd));
                    3: read_bus(1, 7'(a), 8'h42);
                endcase
            end
        end
        // Writes also use every alias, with each write observed independently.
        for (int a = 0; a < 128; a++) begin
            if ((a & 4) == 0) begin
                write_bus(1, 7'(a), 8'(a ^ 8'h5a));
                case (a & 3)
                    0: check(pa_o == 8'(a ^ 8'h5a), "ORA write alias");
                    1: read_bus(1, 1, 8'(a ^ 8'h5a));
                    2: check(pb_o == 8'(a ^ 8'h5a), "ORB write alias");
                    3: read_bus(1, 3, 8'(a ^ 8'h5a));
                endcase
            end else if ((a & 16) == 0) begin
                // Edge control aliases: A3,A6:A5 ignored; A1/A0 select mode.
                pa_i[7] = ((a & 1) == 0);
                reset_chip();
                write_bus(1, 7'(a), 8'hff);
                pa_i[7] = ((a & 1) != 0); idle(1); flags(8'h40);
                check(irq_n == ((a & 2) == 0), "edge-control alias");
                read_bus(1, 7'h05, 8'h40);
            end
        end
        // Every flag-read alias clears PA7 while leaving timer pending.
        for (int a = 0; a < 128; a++) begin
            if ((a & 5) == 5) begin
                pa_i[7] = 1; reset_chip();
                write_bus(1, 7'h06, 0); pa_i[7] = 0; idle(1);
                write_bus(1, 7'h1c, 0); idle(1);
                read_bus(1, 7'(a), 8'hc0); flags(8'h80);
            end
        end
        // All timer load values/rates in Verilator; representative xezim smoke.
        for (int s = 0; s < 4; s++)
            for (int n = 0; n < 256; n++)
                if (!quick || n == 0 || n == 1 || n == 2 || n == 52 || n == 255)
                    timer_case(s, n);

        reset_chip(); pa_i = 8'hff; idle(1);
        write_bus(1, 7'h04, 0); // Falling capture, masked IRQ.
        pa_i[7] = 0; idle(1); flags(8'h40); check(irq_n, "masked edge");
        write_bus(1, 7'h06, 0); check(!irq_n, "enable pending edge");
        read_bus(1, 7'h05, 8'h40); check(irq_n, "edge ack");
        write_bus(1, 7'h07, 0); // Rising capture.
        pa_i[7] = 1; idle(1); flags(8'h40);
        write_bus(1, 7'h1c, 0); idle(1); flags(8'hc0);
        read_bus(1, 7'h0d, 8'hc0); flags(8'h80); check(!irq_n, "flag read leaves timer IRQ");
        // Current fast count is FC after the flag read and two flags probes.
        rs = 1; addr = 7'h04; #1;
        begin
            logic [7:0] observed;
            observed = data_o;
            read_bus(1, 7'h04, observed);
        end
        flags(0); check(irq_n, "timer ack");
        // New edge wins over an interrupt-flag read in the same cycle.
        cs1 = 1; rs = 1; addr = 7'h05; rw = 1; pa_i[7] = 0; tick();
        pa_i[7] = 1; tick(); cs1 = 0; flags(8'h40);
        // Output-mode PA7 still sees resolved-pin edges.
        read_bus(1, 7'h05, 8'h40); write_bus(1, 1, 8'h80);
        pa_i[7] = 0; idle(1); pa_i[7] = 1; idle(1); flags(8'h40);

        reset_chip();
        write_bus(1, 7'h1d, 0); // /8, zero load expires next edge.
        read_bus(1, 7'h0c, 0); flags(8'h80);
        check(!irq_n, "coincident timer read cannot clear new IRQ");
        idle(260); flags(8'h80); // /1 wraps without clearing the latched event.
        // Acknowledgment restores /8; first decrement next edge, then 8 clocks.
        rs = 1; addr = 7'h04; #1;
        begin
            logic [7:0] observed;
            observed = data_o;
            read_bus(1, 7'h04, observed);
            flags(0); idle(1); rs = 1; addr = 7'h04; #1;
            check(data_o == observed-8'd1, "ack restart first decrement");
            idle(7); #1; check(data_o == observed-8'd1, "ack restores divisor");
            idle(1); #1; check(data_o == observed-8'd2, "restored divisor tick");
        end
        write_bus(1, 7'h14, 0); idle(1); flags(8'h80); check(irq_n, "masked timer");
        // Reading enabled alias can assert a new event on a coincident expiry.
        write_bus(1, 7'h14, 0); read_bus(1, 7'h0c, 0);
        check(!irq_n, "read enables timer IRQ");
        // High address mirrors for timer writes and edge control writes.
        for (int mirror = 0; mirror < 4; mirror++) begin
            reset_chip();
            write_bus(1, 7'(mirror*32+28), 0); idle(1);
            read_bus(1, 7'(mirror*32+13), 8'h80);
            check(!irq_n, "mirrored flags do not acknowledge timer");
        end
        $display("MOS 6532 PASS: checks=%0d timer_cases=%0d quick=%0d", checks, timer_cases, quick);
        $finish;
    end
endmodule

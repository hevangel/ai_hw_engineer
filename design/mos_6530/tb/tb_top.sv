`timescale 1ns/1ps
module tb_top;
    logic clk = 0, rst_n = 0, rw = 1;
    logic [12:0] board_addr = 0;
    logic [7:0] data_i = 0;
    logic [7:0] data_2, data_3;
    logic oe_2, oe_3, irq_2, irq_3;
    logic [7:0] pa_i = 8'hff, pb_i = 8'hff;
    logic [7:0] pa_2, pb_2, pa_oe_2, pb_oe_2;
    logic [7:0] pa_3, pb_3, pa_oe_3, pb_oe_3;
    logic [7:0] rom_2 [0:1023], rom_3 [0:1023];
    bit quick;
    int checks = 0, timer_cases = 0;
    mos_6530_kim chip_2 (
        .clk, .rst_n, .rw, .board_addr, .data_i, .data_o(data_2), .data_oe(oe_2),
        .pa_i, .pb_i, .pa_o(pa_2), .pb_o(pb_2), .pa_oe(pa_oe_2), .pb_oe(pb_oe_2), .irq_n(irq_2)
    );
    mos_6530_kim #(.SECOND(1)) chip_3 (
        .clk, .rst_n, .rw, .board_addr, .data_i, .data_o(data_3), .data_oe(oe_3),
        .pa_i, .pb_i, .pa_o(pa_3), .pb_o(pb_3), .pa_oe(pa_oe_3), .pb_oe(pb_oe_3), .irq_n(irq_3)
    );
    task automatic check(input bit ok, input string what);
        checks++;
        if (!ok) $fatal(1, "%s addr=%04x data=%02x/%02x t=%0t", what, board_addr, data_2, data_3, $time);
    endtask
    task automatic tick;
        clk = 1; #1; clk = 0; #1;
    endtask
    task automatic idle(input int n);
        board_addr = 0; rw = 1; repeat (n) tick();
    endtask
    task automatic reset_chip;
        rst_n = 0; idle(1); rst_n = 1;
    endtask
    task automatic write_bus(input logic [12:0] a, input logic [7:0] value);
        board_addr = a; rw = 0; data_i = value; tick(); rw = 1; board_addr = 0;
    endtask
    task automatic read_bus(input logic [12:0] a, input bit second, input logic [7:0] expected);
        board_addr = a; rw = 1; clk = 1; #1;
        check(second ? (oe_3 && !oe_2 && data_3 === expected) :
                       (oe_2 && !oe_3 && data_2 === expected), "shared bus read");
        clk = 0; #1; check(!oe_2 && !oe_3, "low phase bus release"); board_addr = 0;
    endtask
    task automatic peek(input logic [12:0] a, input bit second, input logic [7:0] expected);
        board_addr = a; rw = 1; #1;
        check((second ? data_3 : data_2) === expected, "register observation");
    endtask
    task automatic timer_case(input bit second, input int mode, input int n);
        int p, deadline;
        logic [12:0] base;
        logic [7:0] expected;
        case (mode)
            0: p = 1; 1: p = 8; 2: p = 64; default: p = 1024;
        endcase
        base = second ? 13'h1700 : 13'h1740;
        reset_chip(); write_bus(base + 12 + 13'(mode), 8'(n));
        deadline = n*p+1;
        for (int elapsed = 0; elapsed <= deadline+2; elapsed++) begin
            if (elapsed == 0) expected = 8'(n);
            else if (elapsed < deadline) expected = 8'(n-1-(elapsed-1)/p);
            else expected = 8'(255-(elapsed-deadline));
            peek(base+4, second, expected);
            check((second ? irq_3 : irq_2) == (elapsed < deadline), "timer deadline");
            check((second ? pb_oe_3[7] : pb_oe_2[7]) == (elapsed >= deadline), "PB7 IRQ drive");
            if (elapsed != deadline+2) idle(1);
        end
        timer_cases++;
    endtask

    initial begin
        quick = $test$plusargs("quick");
        $readmemh("references/6530-002.hex", rom_2);
        $readmemh("references/6530-003.hex", rom_3);
        reset_chip();
        for (int a = 0; a < 64; a++) begin
            write_bus(13'h17c0+13'(a), 8'(a));
            write_bus(13'h1780+13'(a), 8'(a ^ 255));
        end
        reset_chip();
        // All unexpanded board addresses, including unmapped bus release.
        for (int a = 0; a < 8192; a++) begin
            board_addr = 13'(a); clk = 1; #1;
            check(!(oe_2 && oe_3), "mutually exclusive masks");
            if (a >= 'h1c00) check(oe_2 && data_2 === rom_2[a-'h1c00], "002 original mask ROM");
            else if (a >= 'h1800) check(oe_3 && data_3 === rom_3[a-'h1800], "003 original mask ROM");
            else if (a >= 'h17c0 && a <= 'h17ff) check(oe_2 && data_2 === 8'(a-'h17c0), "002 RAM");
            else if (a >= 'h1780 && a <= 'h17bf) check(oe_3 && data_3 === 8'((a-'h1780)^255), "003 RAM");
            else if (a >= 'h1700 && a < 'h1780) begin
                check(a < 'h1740 ? oe_3 : oe_2, "IO mask select");
            end else check(!oe_2 && !oe_3, "unmapped bus floats");
            clk = 0; #1;
        end
        for (int a = 0; a < 1024; a++) begin
            write_bus(13'h1c00+13'(a), ~rom_2[a]);
            read_bus(13'h1c00+13'(a), 0, rom_2[a]);
            write_bus(13'h1800+13'(a), ~rom_3[a]);
            read_bus(13'h1800+13'(a), 1, rom_3[a]);
        end
        pa_i = 8'h3c; pb_i = 8'h96;
        for (int variant = 0; variant < 2; variant++) begin
            logic [12:0] base;
            base = variant == 0 ? 13'h1740 : 13'h1700;
            write_bus(base, 8'ha5); write_bus(base+2, 8'h69);
            for (int d = 0; d < 256; d++) begin
                logic [7:0] expected_b;
                write_bus(base+1, 8'(d)); write_bus(base+3, 8'(255-d));
                // PB6 is K5 low on IO accesses, permanently reserved from drive.
                expected_b = (8'h69 & 8'(255-d) & 8'hbf) | (8'h96 & (8'(d) | 8'h40));
                read_bus(base, variant != 0, (8'ha5 & 8'(d)) | (8'h3c & ~8'(d)));
                read_bus(base+2, variant != 0, expected_b);
                check(!(pb_oe_2[6] || pb_oe_3[6]), "reserved PB6 cannot drive select");
                check((variant == 0 ? pa_oe_2 : pa_oe_3) == 8'(d), "PA DDR");
                check((variant == 0 ? pb_oe_2 : pb_oe_3) == (8'(255-d) & 8'hbf), "PB DDR and select ownership");
                check((variant == 0 ? pb_2 : pb_3) == (8'h69 | 8'(d & 128)), "PB value and idle IRQ level");
            end
            // All 64 register aliases; writes observed on the same physical pins.
            reset_chip();
            for (int offset = 0; offset < 64; offset++) begin
                if ((offset & 4) == 0) begin
                    write_bus(base+13'(offset), 8'(offset));
                    case (offset & 3)
                        0: check((variant == 0 ? pa_2 : pa_3) == 8'(offset), "PA alias");
                        1: read_bus(base+1, variant != 0, 8'(offset));
                        2: check((variant == 0 ? pb_2[6:0] : pb_3[6:0]) == 7'(offset), "PB alias");
                        3: read_bus(base+3, variant != 0, 8'(offset));
                    endcase
                end
            end
            for (int offset = 0; offset < 64; offset++) begin
                if ((offset & 4) != 0) begin
                    reset_chip();
                    write_bus(base+13'(offset), 0); idle(1);
                    check((variant == 0 ? irq_2 : irq_3) == ((offset & 8) == 0), "timer-write alias IRQ option");
                    read_bus(base+13'(offset | 1), variant != 0, 8'h80);
                    peek(variant == 0 ? 13'h1705 : 13'h1745, variant == 0, 0);
                    read_bus(base+13'(offset & 62), variant != 0, 8'hfe);
                    check(variant == 0 ? irq_2 : irq_3, "timer-read alias acknowledges");
                    peek(base+13'(offset | 1), variant != 0, 0);
                end
            end
        end
        for (int s = 0; s < 4; s++)
            for (int n = 0; n < 256; n++)
                if (!quick || n == 0 || n == 1 || n == 2 || n == 52 || n == 255) begin
                    timer_case(0, s, n); timer_case(1, s, n);
                end
        for (int variant = 0; variant < 2; variant++) begin
            logic [12:0] base;
            logic [7:0] observed;
            base = variant == 0 ? 13'h1740 : 13'h1700;
            reset_chip(); write_bus(base+13, 0); idle(1);
            read_bus(base+7, variant != 0, 8'h80); // Status read leaves flag.
            peek(base+4, variant != 0, 8'hfe);
            observed = variant == 0 ? data_2 : data_3;
            read_bus(base+14, variant != 0, observed); // Post-expiry enabled alias disables IRQ.
            check(variant == 0 ? irq_2 : irq_3, "post-expiry read disables IRQ regardless of A3");
            idle(1); peek(base+4, variant != 0, observed-8'd1);
            idle(7); peek(base+4, variant != 0, observed-8'd1);
            idle(1); peek(base+4, variant != 0, observed-8'd2);
            reset_chip(); write_bus(base+12, 0);
            read_bus(base+12, variant != 0, 0); // Same-edge underflow is retained.
            check(!(variant == 0 ? irq_2 : irq_3), "read coincident with expiry retains IRQ");
            write_bus(base+2, 8'h80); write_bus(base+3, 8'h80);
            check(variant == 0 ? irq_2 : irq_3, "GPIO PB7 high overrides timer");
            write_bus(base+2, 0);
            check(!(variant == 0 ? irq_2 : irq_3), "GPIO PB7 low shares physical IRQ pin");
            write_bus(base+3, 0);
            check(!(variant == 0 ? irq_2 : irq_3), "pending timer resumes PB7 drive");
            read_bus(base+4, variant != 0, 8'hfb);
        end
        $display("MOS 6530 PASS: checks=%0d timer_cases=%0d quick=%0d", checks, timer_cases, quick);
        $finish;
    end
endmodule

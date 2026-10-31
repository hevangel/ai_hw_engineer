`timescale 1ns/1ps
module tb_ttl_74x1627;
    logic [17:0] a_in, b_in, a_out, a_drive, b_drive;
    logic oe_n, dir, cms, ckoen_n, sysclk, ssclk;
    logic clkout, clkout_drive, ssclk_sink;

    ttl_74x1627 dut(.*);

    logic [17:0] stored_ab, stored_ba;

    task automatic tick_sys;
        sysclk = 1'b1;
        #1;
        sysclk = 1'b0;
        #1;
    endtask

    task automatic tick_ss;
        ssclk = 1'b1;
        #1;
        ssclk = 1'b0;
        #1;
    endtask

    task automatic expect_state(input logic [17:0] exp_a, input logic a_en,
                                input logic [17:0] exp_bsink, input logic b_en,
                                input logic exp_clkout, input logic clk_en,
                                input logic exp_ss_sink);
        if (a_out !== (a_en ? exp_a : '0))
            $fatal(1, "1627 A data: got %05x want %05x", a_out, exp_a);
        for (int k = 0; k < 18; k++)
            if (a_drive[k] !== a_en)
                $fatal(1, "1627 A drive bit %0d", k);
        if (b_drive !== (b_en ? exp_bsink : '0))
            $fatal(1, "1627 B sink: got %05x want %05x", b_drive, exp_bsink);
        if (clkout !== (clk_en ? exp_clkout : 1'b0) ||
            clkout_drive !== clk_en)
            $fatal(1, "1627 CLKOUT state wrong");
        if (ssclk_sink !== exp_ss_sink)
            $fatal(1, "1627 SSCLK sink wrong: got %0b", ssclk_sink);
    endtask

    initial begin
        oe_n = 1'b0;
        dir = 1'b0;
        cms = 1'b0;
        ckoen_n = 1'b0;
        sysclk = 1'b0;
        ssclk = 1'b0;
        a_in = '0;
        b_in = '0;
        #1;

        // A-to-B source-synchronous: registered storage on SYSCLK edges,
        // CLKOUT = SYSCLK, SSCLK bus sinks SYSCLK.
        a_in = 18'h155AA;
        b_in = 18'h0A555;
        tick_sys();
        stored_ab = a_in;
        #1;
        expect_state('0, 1'b0, ~stored_ab, 1'b1, 1'b0, 1'b1, 1'b0);
        a_in = 18'h0C3A5;
        #1;
        expect_state('0, 1'b0, ~stored_ab, 1'b1, 1'b0, 1'b1, 1'b0);
        sysclk = 1'b1;
        #1;
        stored_ab = a_in;
        expect_state('0, 1'b0, ~stored_ab, 1'b1, 1'b1, 1'b1, 1'b1);
        sysclk = 1'b0;
        #1;
        expect_state('0, 1'b0, ~stored_ab, 1'b1, 1'b0, 1'b1, 1'b0);

        // Data isolation: B released while the A register keeps capturing.
        oe_n = 1'b1;
        #1;
        expect_state('0, 1'b0, '0, 1'b0, 1'b0, 1'b1, 1'b0);
        tick_sys();
        stored_ab = a_in;
        expect_state('0, 1'b0, '0, 1'b0, 1'b0, 1'b1, 1'b0);
        oe_n = 1'b0;
        #1;
        expect_state('0, 1'b0, ~stored_ab, 1'b1, 1'b0, 1'b1, 1'b0);

        // Transparent transmission of A with clock outputs released.
        ckoen_n = 1'b1;
        #1;
        expect_state('0, 1'b0, ~a_in, 1'b1, 1'b0, 1'b0, 1'b0);
        oe_n = 1'b1;
        #1;
        expect_state('0, 1'b0, '0, 1'b0, 1'b0, 1'b0, 1'b0);
        oe_n = 1'b0;
        ckoen_n = 1'b0;
        #1;

        // B-to-A source-synchronous: SSCLK is the input clock, CLKOUT = SSCLK.
        dir = 1'b1;
        cms = 1'b0;
        #1;
        tick_ss();
        stored_ba = b_in;
        expect_state(stored_ba, 1'b1, '0, 1'b0, 1'b0, 1'b1, 1'b0);
        ssclk = 1'b1;
        #1;
        expect_state(stored_ba, 1'b1, '0, 1'b0, 1'b1, 1'b1, 1'b0);
        ssclk = 1'b0;
        #1;
        b_in = 18'h3FFFF;
        tick_ss();
        stored_ba = 18'h3FFFF;
        #1;
        expect_state(stored_ba, 1'b1, '0, 1'b0, 1'b0, 1'b1, 1'b0);
        ssclk = 1'b1;
        #1;
        expect_state(stored_ba, 1'b1, '0, 1'b0, 1'b1, 1'b1, 1'b0);
        ssclk = 1'b0;
        #1;

        // B-to-A clock-synchronous: SSCLK sinks SYSCLK, register reads SYSCLK.
        cms = 1'b1;
        #1;
        tick_sys();
        stored_ba = b_in;
        expect_state(stored_ba, 1'b1, '0, 1'b0, 1'b0, 1'b1, 1'b0);
        sysclk = 1'b1;
        #1;
        expect_state(stored_ba, 1'b1, '0, 1'b0, 1'b1, 1'b1, 1'b1);
        sysclk = 1'b0;
        #1;

        // Transparent transmission of B; clocks released.
        ckoen_n = 1'b1;
        #1;
        expect_state(b_in, 1'b1, '0, 1'b0, 1'b0, 1'b0, 1'b0);

        // Receive SSCLK: clock-only forwarding while data stays isolated.
        oe_n = 1'b1;
        ckoen_n = 1'b0;
        cms = 1'b0;
        #1;
        ssclk = 1'b1;
        #1;
        expect_state('0, 1'b0, '0, 1'b0, 1'b1, 1'b1, 1'b0);
        ssclk = 1'b0;
        #1;
        expect_state('0, 1'b0, '0, 1'b0, 1'b0, 1'b1, 1'b0);

        $display("PASS: tb_ttl_74x1627");
        $finish;
    end
endmodule

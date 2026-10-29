`timescale 1ns/1ps
module tb_ttl_74x16600;
    logic [17:0] a_in, b_in, a_out, b_out;
    logic oeab_n, oeba_n, leab, leba;
    logic clkab_n, clkba_n, clkenab_n, clkenba_n;
    logic ab_drive, ba_drive;
    logic [17:0] expected_ab, expected_ba;

    ttl_74x16600 dut(.*);

    task automatic check_outputs;
        #1;
        if (ab_drive !== !oeab_n || ba_drive !== !oeba_n ||
            b_out !== (ab_drive ? expected_ab : 18'h00000) ||
            a_out !== (ba_drive ? expected_ba : 18'h00000))
            $fatal(1, "16600 direction, storage, or output-enable mismatch");
    endtask

    initial begin
        a_in = 18'h12345;
        b_in = 18'h2ABCD;
        oeab_n = 1'b0;
        oeba_n = 1'b0;
        leab = 1'b1;
        leba = 1'b1;
        clkab_n = 1'b1;
        clkba_n = 1'b1;
        clkenab_n = 1'b1;
        clkenba_n = 1'b1;
        expected_ab = a_in;
        expected_ba = b_in;
        check_outputs();

        a_in = 18'h2D13A;
        b_in = 18'h05E67;
        expected_ab = a_in;
        expected_ba = b_in;
        check_outputs();

        leab = 1'b0;
        leba = 1'b0;
        a_in = 18'h0A55A;
        b_in = 18'h1C3E7;
        check_outputs();

        // Active-high clock-enable pins are overbarred in the source: high holds.
        clkenab_n = 1'b1;
        clkab_n = 1'b0;
        clkenba_n = 1'b1;
        clkba_n = 1'b0;
        check_outputs();
        clkab_n = 1'b1;
        clkba_n = 1'b1;
        check_outputs();

        // A low clock-enable level permits capture on the falling clock-pin edge.
        clkenab_n = 1'b0;
        clkenba_n = 1'b0;
        a_in = 18'h2B64D;
        b_in = 18'h14C92;
        clkab_n = 1'b0;
        clkba_n = 1'b0;
        expected_ab = a_in;
        expected_ba = b_in;
        check_outputs();

        a_in = 18'h001FE;
        b_in = 18'h3FF01;
        check_outputs();
        clkab_n = 1'b1;
        clkba_n = 1'b1;
        check_outputs();

        oeab_n = 1'b1;
        oeba_n = 1'b1;
        check_outputs();
        oeab_n = 1'b0;
        oeba_n = 1'b0;
        check_outputs();

        // Transparent operation follows each bus even when its clock enable is high.
        clkenab_n = 1'b1;
        clkenba_n = 1'b1;
        leab = 1'b1;
        leba = 1'b1;
        a_in = 18'h34567;
        b_in = 18'h21ABC;
        expected_ab = a_in;
        expected_ba = b_in;
        check_outputs();

        // Independent output enables isolate just one direction.
        oeab_n = 1'b1;
        check_outputs();
        oeab_n = 1'b0;
        oeba_n = 1'b1;
        check_outputs();

        $display("PASS: tb_ttl_74x16600");
        $finish;
    end
endmodule

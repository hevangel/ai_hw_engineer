`timescale 1ns/1ps
module tb_ttl_74x885;
    logic l_a_n, ple, p_gt_qin, p_lt_qin;
    logic [7:0] p, q;
    logic p_gt_qout, p_lt_qout;
    ttl_74x885 dut(.*);
    int errors;
    initial begin
        errors = 0;
        ple = 1; l_a_n = 1; p_gt_qin = 0; p_lt_qin = 0;

        // Unsigned: 7 > 3.
        p = 8'd7; q = 8'd3; #1;
        if (p_gt_qout !== 1 || p_lt_qout !== 0) errors++;

        // Unsigned: 3 < 7.
        p = 8'd3; q = 8'd7; #1;
        if (p_gt_qout !== 0 || p_lt_qout !== 1) errors++;

        // Equal — pass cascade.
        p = 8'd5; q = 8'd5; p_gt_qin = 1; p_lt_qin = 0; #1;
        if (p_gt_qout !== 1 || p_lt_qout !== 0) errors++;
        p_gt_qin = 0; p_lt_qin = 1; #1;
        if (p_gt_qout !== 0 || p_lt_qout !== 1) errors++;
        p_lt_qin = 0;

        // Arithmetic mode: 0xFF (= -1 signed) vs 0x01 (= +1 signed).
        l_a_n = 0;
        p = 8'hFF; q = 8'h01; #1;
        if (p_gt_qout !== 0 || p_lt_qout !== 1) errors++;
        // In unsigned mode the same operands give the opposite result.
        l_a_n = 1; #1;
        if (p_gt_qout !== 1 || p_lt_qout !== 0) errors++;

        // Latch: capture then change p while ple low.
        l_a_n = 1; ple = 1; p = 8'd10; q = 8'd5; #1;
        ple = 0; p = 8'd0; #1;
        // p_lat still 10 > 5.
        if (p_gt_qout !== 1) errors++;

        if (errors != 0) $fatal(1, "tb_ttl_74x885: %0d errors", errors);
        $display("PASS: tb_ttl_74x885");
        $finish;
    end
endmodule

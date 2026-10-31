`timescale 1ns/1ps
module tb_ttl_74x5074;
    logic clk1, clr1_n, pre1_n, d1, q1, q1_n;
    logic clk2, clr2_n, pre2_n, d2, q2, q2_n;
    ttl_74x5074 dut(.*);
    int errors;
    task tick1; #1; clk1 = 1; #1; clk1 = 0; endtask
    initial begin
        errors = 0;
        clk1 = 0; clk2 = 0; d1 = 0; d2 = 0;
        clr1_n = 1; pre1_n = 1; clr2_n = 1; pre2_n = 1; #1;
        clr1_n = 0; clr2_n = 0; #1; clr1_n = 1; clr2_n = 1; #1;
        if (q1 !== 0) errors++;
        d1 = 1; tick1; tick1;
        if (q1 !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x5074: %0d errors", errors);
        $display("PASS: tb_ttl_74x5074");
        $finish;
    end
endmodule

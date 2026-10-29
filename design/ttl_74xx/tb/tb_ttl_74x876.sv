`timescale 1ns/1ps
module tb_ttl_74x876;
    logic clk1, pre1_n, oe1_n;
    logic [3:0] d1, q1;
    logic q1_oe_n;
    logic clk2, pre2_n, oe2_n;
    logic [3:0] d2, q2;
    logic q2_oe_n;
    ttl_74x876 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk1 = 0; clk2 = 0; pre1_n = 1; pre2_n = 1;
        oe1_n = 0; oe2_n = 0; d1 = 0; d2 = 0; #1;
        // Async preset pulse to initialize both flops.
        pre1_n = 0; pre2_n = 0; #1;
        if (q1 !== 0 || q2 !== 0) errors++;  // latch=F → ~F=0
        pre1_n = 1; pre2_n = 1;
        d1 = 4'h6; clk1 = 1; #1;
        // Q = ~6 = 9.
        if (q1 !== 4'h9) errors++;
        pre1_n = 0; #1;
        if (q1 !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x876: %0d errors", errors);
        $display("PASS: tb_ttl_74x876");
        $finish;
    end
endmodule

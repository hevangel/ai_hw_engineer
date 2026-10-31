`timescale 1ns/1ps
module tb_ttl_74x7076;
    logic [1:0] inv_a, inv_y, nor_a, nor_b, nor_y;
    logic clk1, clr1_n, pre1_n, d1, q1, q1_n;
    logic clk2, clr2_n, pre2_n, d2, q2, q2_n;
    ttl_74x7076 dut(.*);
    int errors;
    initial begin
        errors = 0;
        inv_a = 2'b11; nor_a = 2'b00; nor_b = 2'b01;
        clk1 = 0; clk2 = 0; d1 = 0; d2 = 0;
        clr1_n = 1; pre1_n = 1; clr2_n = 1; pre2_n = 1;
        #1; clr1_n = 0; clr2_n = 0; #1; clr1_n = 1; clr2_n = 1; #1;
        if (inv_y !== 2'b00 || nor_y !== 2'b10) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x7076: %0d errors", errors);
        $display("PASS: tb_ttl_74x7076");
        $finish;
    end
endmodule

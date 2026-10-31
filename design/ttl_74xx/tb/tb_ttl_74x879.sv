`timescale 1ns/1ps
module tb_ttl_74x879;
    logic clk1, sclr1_n, oe1_n;
    logic [3:0] d1, q1;
    logic q1_oe_n;
    logic clk2, sclr2_n, oe2_n;
    logic [3:0] d2, q2;
    logic q2_oe_n;
    ttl_74x879 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk1 = 0; clk2 = 0; sclr1_n = 1; sclr2_n = 1; oe1_n = 0; oe2_n = 0;
        d1 = 4'h6; d2 = 0; clk1 = 1; #1;
        if (q1 !== 4'h9) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x879: %0d errors", errors);
        $display("PASS: tb_ttl_74x879");
        $finish;
    end
endmodule

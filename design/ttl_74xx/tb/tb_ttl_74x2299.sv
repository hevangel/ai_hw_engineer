`timescale 1ns/1ps
module tb_ttl_74x2299;
    logic clk, clr_n, oe_n, s0, s1, din_right, din_left;
    logic [7:0] p, q;
    ttl_74x2299 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; clr_n = 0; oe_n = 0; s0 = 1; s1 = 1; din_right = 0; din_left = 0; p = 8'h55;
        #1; if (q !== 0) errors++;
        clr_n = 1; clk = 1; #1;
        if (q !== 8'h55) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2299: %0d errors", errors);
        $display("PASS: tb_ttl_74x2299");
        $finish;
    end
endmodule

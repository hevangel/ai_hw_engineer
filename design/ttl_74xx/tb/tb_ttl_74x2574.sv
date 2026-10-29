`timescale 1ns/1ps
module tb_ttl_74x2574;
    logic clk, oe_n;
    logic [7:0] d, q;
    logic hiz;
    ttl_74x2574 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; oe_n = 0; d = 8'h3C; #1; clk = 1; #1;
        if (q !== 8'h3C) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2574: %0d errors", errors);
        $display("PASS: tb_ttl_74x2574");
        $finish;
    end
endmodule

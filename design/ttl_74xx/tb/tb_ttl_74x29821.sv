`timescale 1ns/1ps
module tb_ttl_74x29821;
    logic clk, oe_n;
    logic [9:0] d, q;
    logic hiz;
    ttl_74x29821 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; oe_n = 0; d = 10'h1AA; #1; clk = 1; #1;
        if (q !== 10'h1AA) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x29821: %0d errors", errors);
        $display("PASS: tb_ttl_74x29821");
        $finish;
    end
endmodule

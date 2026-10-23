`timescale 1ns/1ps
module tb_ttl_74x16722;
    logic clk, oe_n;
    logic [21:0] d, q;
    ttl_74x16722 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; oe_n = 0; d = 22'h12345A; #1; clk = 1; #1;
        if (q !== 22'h12345A) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x16722: %0d errors", errors);
        $display("PASS: tb_ttl_74x16722");
        $finish;
    end
endmodule

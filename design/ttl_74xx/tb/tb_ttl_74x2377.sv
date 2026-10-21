`timescale 1ns/1ps
module tb_ttl_74x2377;
    logic clk, ce_n;
    logic [7:0] d, q;
    ttl_74x2377 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; ce_n = 0; d = 8'hAA; #1; clk = 1; #1;
        if (q !== 8'hAA) errors++;
        ce_n = 1; d = 8'h55; clk = 0; #1; clk = 1; #1;
        if (q !== 8'hAA) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2377: %0d errors", errors);
        $display("PASS: tb_ttl_74x2377");
        $finish;
    end
endmodule

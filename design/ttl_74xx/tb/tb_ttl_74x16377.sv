`timescale 1ns/1ps
module tb_ttl_74x16377;
    logic clk, en_n;
    logic [15:0] d, q;
    ttl_74x16377 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; en_n = 0; d = 16'hABCD; #1; clk = 1; #1;
        if (q !== 16'hABCD) errors++;
        en_n = 1; d = 16'h0; clk = 0; #1; clk = 1; #1;
        if (q !== 16'hABCD) errors++;  // disabled, holds
        if (errors != 0) $fatal(1, "tb_ttl_74x16377: %0d errors", errors);
        $display("PASS: tb_ttl_74x16377");
        $finish;
    end
endmodule

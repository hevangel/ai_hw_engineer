`timescale 1ns/1ps
module tb_ttl_74x162721;
    logic clk, oe_n;
    logic [19:0] d, q;
    ttl_74x162721 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; oe_n = 0; d = 20'h12345; #1; clk = 1; #1;
        if (q !== 20'h12345) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x162721: %0d errors", errors);
        $display("PASS: tb_ttl_74x162721");
        $finish;
    end
endmodule

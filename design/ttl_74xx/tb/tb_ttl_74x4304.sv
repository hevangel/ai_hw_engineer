`timescale 1ns/1ps
module tb_ttl_74x4304;
    logic clk, oe_n;
    logic [7:0] d, q;
    logic hiz;
    ttl_74x4304 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; oe_n = 0; d = 8'hA5;
        #1; clk = 1; #1;
        if (q !== 8'hA5) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x4304: %0d errors", errors);
        $display("PASS: tb_ttl_74x4304");
        $finish;
    end
endmodule

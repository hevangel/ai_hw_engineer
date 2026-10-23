`timescale 1ns/1ps
module tb_ttl_74x322374;
    logic clk, oe_n;
    logic [31:0] d, q;
    logic hiz;
    ttl_74x322374 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; oe_n = 0; d = 32'h89ABCDEF; #1; clk = 1; #1;
        if (q !== 32'h89ABCDEF) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x322374: %0d errors", errors);
        $display("PASS: tb_ttl_74x322374");
        $finish;
    end
endmodule

`timescale 1ns/1ps
module tb_ttl_74x162374;
    logic clk, oe_n;
    logic [15:0] d, q;
    ttl_74x162374 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; oe_n = 0; d = 16'h1234; #1; clk = 1; #1;
        if (q !== 16'h1234) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x162374: %0d errors", errors);
        $display("PASS: tb_ttl_74x162374");
        $finish;
    end
endmodule

`timescale 1ns/1ps
module tb_ttl_74x16374;
    logic clk, oe_n;
    logic [15:0] d, q;
    ttl_74x16374 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; oe_n = 0; d = 16'hDEAD; #1; clk = 1; #1;
        if (q !== 16'hDEAD) errors++;
        d = 16'hBEEF; clk = 0; #1; clk = 1; #1;
        if (q !== 16'hBEEF) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x16374: %0d errors", errors);
        $display("PASS: tb_ttl_74x16374");
        $finish;
    end
endmodule

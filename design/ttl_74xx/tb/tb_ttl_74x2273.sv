`timescale 1ns/1ps
module tb_ttl_74x2273;
    logic clk, clr_n;
    logic [7:0] d, q;
    ttl_74x2273 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; clr_n = 0; d = 8'hAB; #1;
        if (q !== 0) errors++;
        clr_n = 1; clk = 1; #1;
        if (q !== 8'hAB) errors++;
        clr_n = 0; #1;
        if (q !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2273: %0d errors", errors);
        $display("PASS: tb_ttl_74x2273");
        $finish;
    end
endmodule

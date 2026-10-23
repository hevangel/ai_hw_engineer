`timescale 1ns/1ps
module tb_ttl_74x2374;
    logic clk, oe_n;
    logic [7:0] d, q;
    ttl_74x2374 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; oe_n = 0; d = 8'h5A; #1; clk = 1; #1;
        if (q !== 8'h5A) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2374: %0d errors", errors);
        $display("PASS: tb_ttl_74x2374");
        $finish;
    end
endmodule

`timescale 1ns/1ps
module tb_ttl_74x4303;
    logic clk, oe_n;
    logic [7:0] d, q;
    logic hiz;
    ttl_74x4303 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; oe_n = 0; d = 8'h0F;
        #1; clk = 1; #1;
        if (q !== 8'hF0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x4303: %0d errors", errors);
        $display("PASS: tb_ttl_74x4303");
        $finish;
    end
endmodule

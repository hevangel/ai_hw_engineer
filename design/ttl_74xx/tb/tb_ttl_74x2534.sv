`timescale 1ns/1ps
module tb_ttl_74x2534;
    logic clk, oe_n;
    logic [7:0] d, q_n;
    logic hiz;
    ttl_74x2534 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; oe_n = 0; d = 8'h0F; #1; clk = 1; #1;
        if (q_n !== 8'hF0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2534: %0d errors", errors);
        $display("PASS: tb_ttl_74x2534");
        $finish;
    end
endmodule

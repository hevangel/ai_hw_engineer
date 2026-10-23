`timescale 1ns/1ps
module tb_ttl_74x3827;
    logic oe_n;
    logic [9:0] a, y;
    logic hiz;
    ttl_74x3827 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; a = 10'h2C5; #1;
        if (y !== 10'h2C5) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x3827: %0d errors", errors);
        $display("PASS: tb_ttl_74x3827");
        $finish;
    end
endmodule

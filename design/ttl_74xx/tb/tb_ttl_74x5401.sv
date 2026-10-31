`timescale 1ns/1ps
module tb_ttl_74x5401;
    logic oe_n;
    logic [10:0] a, y;
    logic hiz;
    ttl_74x5401 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; a = 11'h333; #1;
        if (y !== 11'h4CC) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x5401: %0d errors", errors);
        $display("PASS: tb_ttl_74x5401");
        $finish;
    end
endmodule

`timescale 1ns/1ps
module tb_ttl_74x5400;
    logic oe_n;
    logic [10:0] a, y;
    logic hiz;
    ttl_74x5400 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; a = 11'h5A3; #1;
        if (y !== 11'h5A3) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x5400: %0d errors", errors);
        $display("PASS: tb_ttl_74x5400");
        $finish;
    end
endmodule

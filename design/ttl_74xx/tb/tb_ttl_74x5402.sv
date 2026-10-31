`timescale 1ns/1ps
module tb_ttl_74x5402;
    logic oe_n;
    logic [11:0] a, y;
    logic hiz;
    ttl_74x5402 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; a = 12'h5A5; #1;
        if (y !== 12'h5A5) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x5402: %0d errors", errors);
        $display("PASS: tb_ttl_74x5402");
        $finish;
    end
endmodule

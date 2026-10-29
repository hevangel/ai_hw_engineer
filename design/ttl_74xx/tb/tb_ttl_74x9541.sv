`timescale 1ns/1ps
module tb_ttl_74x9541;
    logic oe_n, inv;
    logic [7:0] a, y;
    logic hiz;
    ttl_74x9541 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; inv = 1; a = 8'h55; #1;
        if (y !== 8'hAA) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x9541: %0d errors", errors);
        $display("PASS: tb_ttl_74x9541");
        $finish;
    end
endmodule

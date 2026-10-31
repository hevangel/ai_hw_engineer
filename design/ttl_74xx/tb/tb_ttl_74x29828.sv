`timescale 1ns/1ps
module tb_ttl_74x29828;
    logic oe_n;
    logic [9:0] a, y;
    logic hiz;
    ttl_74x29828 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; a = 10'h0F0; #1;
        if (y !== 10'h30F) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x29828: %0d errors", errors);
        $display("PASS: tb_ttl_74x29828");
        $finish;
    end
endmodule

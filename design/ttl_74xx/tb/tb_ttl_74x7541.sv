`timescale 1ns/1ps
module tb_ttl_74x7541;
    logic oe1_n, oe2_n;
    logic [7:0] a, y;
    logic hiz;
    ttl_74x7541 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe1_n = 0; oe2_n = 0; a = 8'hC3; #1;
        if (y !== 8'hC3) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x7541: %0d errors", errors);
        $display("PASS: tb_ttl_74x7541");
        $finish;
    end
endmodule

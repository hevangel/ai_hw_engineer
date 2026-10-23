`timescale 1ns/1ps
module tb_ttl_74x2541;
    logic g1_n, g2_n;
    logic [7:0] a, y;
    logic hiz;
    ttl_74x2541 dut(.*);
    int errors;
    initial begin
        errors = 0;
        g1_n = 0; g2_n = 0; a = 8'h5A; #1;
        if (y !== 8'h5A) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2541: %0d errors", errors);
        $display("PASS: tb_ttl_74x2541");
        $finish;
    end
endmodule

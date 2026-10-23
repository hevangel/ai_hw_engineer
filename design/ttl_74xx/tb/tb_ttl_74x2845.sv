`timescale 1ns/1ps
module tb_ttl_74x2845;
    logic oe1_n, oe2_n, le, rst_n;
    logic [7:0] d, q;
    logic hiz;
    ttl_74x2845 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe1_n = 0; oe2_n = 0; le = 1; d = 8'h69;
        rst_n = 1; #1; rst_n = 0; #1; rst_n = 1; #1;
        if (q !== 8'h69) errors++;
        oe1_n = 1; #1;
        if (hiz !== 1) errors++;
        oe1_n = 0; oe2_n = 1; #1;
        if (hiz !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2845: %0d errors", errors);
        $display("PASS: tb_ttl_74x2845");
        $finish;
    end
endmodule

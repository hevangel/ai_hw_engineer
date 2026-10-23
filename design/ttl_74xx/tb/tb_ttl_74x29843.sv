`timescale 1ns/1ps
module tb_ttl_74x29843;
    logic oe_n, le, rst_n;
    logic [8:0] d, q;
    logic hiz;
    ttl_74x29843 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; le = 1; d = 9'h1FE; rst_n = 1; #1;
        if (q !== 9'h1FE) errors++;
        rst_n = 0; #1;
        if (q !== 9'h000) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x29843: %0d errors", errors);
        $display("PASS: tb_ttl_74x29843");
        $finish;
    end
endmodule

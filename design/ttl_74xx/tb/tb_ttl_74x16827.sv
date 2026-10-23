`timescale 1ns/1ps
module tb_ttl_74x16827;
    logic [19:0] a, y;
    logic oe1_n, oe2_n;
    ttl_74x16827 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe1_n = 0; oe2_n = 0; a = 20'hAABBC; #1;
        if (y !== 20'hAABBC) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x16827: %0d errors", errors);
        $display("PASS: tb_ttl_74x16827");
        $finish;
    end
endmodule

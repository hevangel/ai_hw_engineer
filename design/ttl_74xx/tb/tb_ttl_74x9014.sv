`timescale 1ns/1ps
module tb_ttl_74x9014;
    logic oe_n;
    logic [8:0] a, y;
    logic hiz;
    ttl_74x9014 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; a = 9'h0AA; #1;
        if (y !== 9'h155) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x9014: %0d errors", errors);
        $display("PASS: tb_ttl_74x9014");
        $finish;
    end
endmodule

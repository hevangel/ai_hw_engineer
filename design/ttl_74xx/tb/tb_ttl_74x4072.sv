`timescale 1ns/1ps
module tb_ttl_74x4072;
    logic [3:0] a, b;
    logic [1:0] y;
    ttl_74x4072 dut(.*);
    int errors;
    initial begin
        errors = 0;
        a = 4'b0000; b = 4'b0001; #1;
        if (y[0] !== 0 || y[1] !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x4072: %0d errors", errors);
        $display("PASS: tb_ttl_74x4072");
        $finish;
    end
endmodule

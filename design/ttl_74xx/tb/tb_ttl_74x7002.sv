`timescale 1ns/1ps
module tb_ttl_74x7002;
    logic [3:0] a, b, y;
    ttl_74x7002 dut(.*);
    int errors;
    initial begin
        errors = 0;
        a = 4'b0000; b = 4'b0000; #1;
        if (y !== 4'b1111) errors++;
        a = 4'b0001; #1;
        if (y !== 4'b1110) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x7002: %0d errors", errors);
        $display("PASS: tb_ttl_74x7002");
        $finish;
    end
endmodule

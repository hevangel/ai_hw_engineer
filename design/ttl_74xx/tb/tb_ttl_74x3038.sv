`timescale 1ns/1ps
module tb_ttl_74x3038;
    logic [3:0] a, b, y;
    ttl_74x3038 dut(.*);
    int errors;
    initial begin
        errors = 0;
        a = 4'b0011; b = 4'b0101; #1;
        if (y !== ~(4'b0011 & 4'b0101)) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x3038: %0d errors", errors);
        $display("PASS: tb_ttl_74x3038");
        $finish;
    end
endmodule

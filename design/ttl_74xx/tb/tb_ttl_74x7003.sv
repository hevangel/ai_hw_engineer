`timescale 1ns/1ps
module tb_ttl_74x7003;
    logic [3:0] a, b, y;
    ttl_74x7003 dut(.*);
    int errors;
    initial begin
        errors = 0;
        a = 4'b1010; b = 4'b1100; #1;
        if (y !== ~(4'b1010 & 4'b1100)) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x7003: %0d errors", errors);
        $display("PASS: tb_ttl_74x7003");
        $finish;
    end
endmodule

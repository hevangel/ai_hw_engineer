`timescale 1ns/1ps
module tb_ttl_74x8003;
    logic [1:0] a, b, y;
    ttl_74x8003 dut(.*);
    int errors;
    initial begin
        errors = 0;
        a = 2'b11; b = 2'b10; #1;
        if (y !== 2'b01) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x8003: %0d errors", errors);
        $display("PASS: tb_ttl_74x8003");
        $finish;
    end
endmodule

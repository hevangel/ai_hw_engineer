`timescale 1ns/1ps
module tb_ttl_74x558;
    logic [7:0] a, b;
    logic [15:0] product;
    ttl_74x558 dut(.*);
    int errors;
    initial begin
        errors=0;
        a=8'd100; b=8'd2; #1; if (product !== 16'd200) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x558: %0d errors", errors);
        $display("PASS: tb_ttl_74x558");
        $finish;
    end
endmodule

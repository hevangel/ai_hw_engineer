`timescale 1ns/1ps
module tb_ttl_74x9135;
    logic oe_n;
    logic [8:0] a, y;
    logic hiz;
    ttl_74x9135 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; a = 9'h0E1; #1;
        if (y !== 9'h0E1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x9135: %0d errors", errors);
        $display("PASS: tb_ttl_74x9135");
        $finish;
    end
endmodule

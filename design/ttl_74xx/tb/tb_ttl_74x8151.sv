`timescale 1ns/1ps
module tb_ttl_74x8151;
    logic oe_n, inv;
    logic [9:0] a, y;
    logic hiz;
    ttl_74x8151 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; inv = 0; a = 10'h2A5; #1;
        if (y !== 10'h2A5) errors++;
        inv = 1; #1;
        if (y !== 10'h15A) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x8151: %0d errors", errors);
        $display("PASS: tb_ttl_74x8151");
        $finish;
    end
endmodule

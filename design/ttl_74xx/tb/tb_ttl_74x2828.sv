`timescale 1ns/1ps
module tb_ttl_74x2828;
    logic oe_n;
    logic [9:0] a, y;
    logic hiz;
    ttl_74x2828 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; a = 10'h155; #1;
        if (y !== 10'h2AA) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2828: %0d errors", errors);
        $display("PASS: tb_ttl_74x2828");
        $finish;
    end
endmodule

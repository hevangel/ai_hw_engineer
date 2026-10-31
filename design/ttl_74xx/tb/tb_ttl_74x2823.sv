`timescale 1ns/1ps
module tb_ttl_74x2823;
    logic clk, oe_n, clr_n;
    logic [8:0] d, q;
    logic hiz;
    ttl_74x2823 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; oe_n = 0; d = 9'h1FF;
        clr_n = 1; #1; clr_n = 0; #1; clr_n = 1; #1;
        if (q !== 9'h000) errors++;
        #1; clk = 1; #1;
        if (q !== 9'h1FF) errors++;
        clr_n = 0; #1;
        if (q !== 9'h000) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2823: %0d errors", errors);
        $display("PASS: tb_ttl_74x2823");
        $finish;
    end
endmodule

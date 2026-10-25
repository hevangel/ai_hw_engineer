`timescale 1ns/1ps
module tb_ttl_74x3284;
    logic clk, oe_n, sel;
    logic [17:0] a, b, y;
    logic hiz;
    ttl_74x3284 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; oe_n = 0; sel = 0;
        a = 18'h2AAAA; b = 18'h15555;
        tick;
        if (y !== 18'h2AAAA) errors++;
        sel = 1; tick;
        if (y !== 18'h15555) errors++;
        oe_n = 1; #1;
        if (hiz !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x3284: %0d errors", errors);
        $display("PASS: tb_ttl_74x3284");
        $finish;
    end
endmodule

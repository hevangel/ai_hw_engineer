`timescale 1ns/1ps
module tb_ttl_74x1823;
    logic clk, clr_n, clken_n, oe_n;
    logic [8:0] d, q;
    logic q_oe_n;
    ttl_74x1823 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; clr_n = 0; clken_n = 0; oe_n = 0; d = 0; #1;
        if (q !== 0) errors++;
        clr_n = 1; d = 9'h0A5; clk = 0; #1; clk = 1; #1;
        if (q !== 9'h0A5) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x1823: %0d errors", errors);
        $display("PASS: tb_ttl_74x1823");
        $finish;
    end
endmodule

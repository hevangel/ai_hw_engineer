`timescale 1ns/1ps
module tb_ttl_74x590;
    logic clk_cnt, clk_reg, ce_n, cclr_n, oe_n, rco_n, hiz;
    logic [7:0] q;
    ttl_74x590 dut(.*);
    task automatic tc; clk_cnt=0; #1; clk_cnt=1; #1; clk_cnt=0; #1; endtask
    task automatic tr; clk_reg=0; #1; clk_reg=1; #1; clk_reg=0; #1; endtask
    int errors;
    initial begin
        errors=0; clk_cnt=0; clk_reg=0; oe_n=0; ce_n=1;
        cclr_n=1; #1; cclr_n=0; #1; cclr_n=1;
        ce_n=0;
        tc; tc; tc; // cnt=3
        tr; if (q !== 8'd3) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x590: %0d errors", errors);
        $display("PASS: tb_ttl_74x590");
        $finish;
    end
endmodule

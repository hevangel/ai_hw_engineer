`timescale 1ns/1ps
module tb_ttl_74x592;
    logic clk_cnt, clk_reg, ce_n, cclr_n, load_n, rco_n;
    logic [7:0] d, q;
    ttl_74x592 dut(.*);
    task automatic tc; clk_cnt=0; #1; clk_cnt=1; #1; clk_cnt=0; #1; endtask
    task automatic tr; clk_reg=0; #1; clk_reg=1; #1; clk_reg=0; #1; endtask
    int errors;
    initial begin
        errors=0; clk_cnt=0; clk_reg=0; ce_n=1; load_n=1;
        cclr_n=1; #1; cclr_n=0; #1; cclr_n=1;
        d=8'd50; tr;
        load_n=0; tc; load_n=1; ce_n=0; tc; tc;
        if (q !== 8'd52) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x592: %0d errors q=%0d", errors, q);
        $display("PASS: tb_ttl_74x592");
        $finish;
    end
endmodule

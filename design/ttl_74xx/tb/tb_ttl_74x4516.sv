`timescale 1ns/1ps
module tb_ttl_74x4516;
    logic clk, rst, load_n, ce_n, up_dn;
    logic [3:0] d, q;
    logic co_n;
    ttl_74x4516 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; load_n = 1; ce_n = 0; up_dn = 1; d = 0; rst = 1; #1; rst = 0; #1;
        for (int i = 0; i < 15; i++) tick;
        if (q !== 4'hF || co_n !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x4516: %0d errors", errors);
        $display("PASS: tb_ttl_74x4516");
        $finish;
    end
endmodule

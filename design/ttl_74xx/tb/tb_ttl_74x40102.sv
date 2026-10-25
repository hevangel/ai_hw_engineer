`timescale 1ns/1ps
module tb_ttl_74x40102;
    logic clk, rst, load_n, ce_n;
    logic [7:0] d, q;
    logic tc_n;
    ttl_74x40102 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; load_n = 1; ce_n = 0; d = 0; rst = 1; #1; rst = 0; #1;
        d = 8'h05; load_n = 0; tick; load_n = 1;
        for (int i = 0; i < 5; i++) tick;
        if (q !== 8'h00 || tc_n !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x40102: %0d errors", errors);
        $display("PASS: tb_ttl_74x40102");
        $finish;
    end
endmodule

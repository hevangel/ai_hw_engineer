`timescale 1ns/1ps
module tb_ttl_74x4510;
    logic clk, rst, load_n, ce_n, up_dn;
    logic [3:0] d, q;
    logic co_n;
    ttl_74x4510 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; load_n = 1; ce_n = 0; up_dn = 1; d = 0; rst = 1; #1; rst = 0; #1;
        for (int i = 0; i < 10; i++) tick;
        if (q !== 4'd0) errors++;  // wraps after 9->0
        // count down from 0
        up_dn = 0; tick;
        if (q !== 4'd9) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x4510: %0d errors", errors);
        $display("PASS: tb_ttl_74x4510");
        $finish;
    end
endmodule

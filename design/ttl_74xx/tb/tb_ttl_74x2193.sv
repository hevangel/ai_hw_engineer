`timescale 1ns/1ps
module tb_ttl_74x2193;
    logic sys_clk, clk_up, clk_dn, clr, load_n;
    logic [3:0] d, q;
    logic co_n, bo_n;
    ttl_74x2193 dut(.*);
    int errors;
    initial begin
        errors = 0;
        sys_clk = 0; clk_up = 0; clk_dn = 0; clr = 1; load_n = 1; d = 0; #1;
        sys_clk = 1; #1; sys_clk = 0; #1;
        if (q !== 0) errors++;
        clr = 0;
        // Load 5.
        load_n = 0; d = 4'd5; sys_clk = 1; #1; sys_clk = 0; #1; load_n = 1;
        if (q !== 4'd5) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2193: %0d errors", errors);
        $display("PASS: tb_ttl_74x2193");
        $finish;
    end
endmodule

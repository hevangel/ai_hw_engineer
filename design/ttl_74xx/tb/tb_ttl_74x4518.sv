`timescale 1ns/1ps
module tb_ttl_74x4518;
    logic clk_a, en_a, rst_a, clk_b, en_b, rst_b;
    logic [3:0] q_a, q_b;
    ttl_74x4518 dut(.*);
    int errors;
    task tick_a; #1; clk_a = 1; #1; clk_a = 0; endtask
    initial begin
        errors = 0;
        clk_a = 0; clk_b = 0; en_a = 1; en_b = 0; rst_a = 1; rst_b = 1; #1;
        rst_a = 0; rst_b = 0; #1;
        for (int i = 0; i < 10; i++) tick_a;
        if (q_a !== 4'd0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x4518: %0d errors", errors);
        $display("PASS: tb_ttl_74x4518");
        $finish;
    end
endmodule

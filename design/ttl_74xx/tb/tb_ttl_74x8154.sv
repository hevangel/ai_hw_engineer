`timescale 1ns/1ps
module tb_ttl_74x8154;
    logic clk_a, en_a, clr_a_n, reg_clk_a;
    logic clk_b, en_b, clr_b_n, reg_clk_b;
    logic [15:0] q_a, q_b;
    ttl_74x8154 dut(.*);
    int errors;
    task tick_a; #1; clk_a = 1; #1; clk_a = 0; endtask
    task reg_a;  #1; reg_clk_a = 1; #1; reg_clk_a = 0; endtask
    initial begin
        errors = 0;
        clk_a = 0; clk_b = 0; reg_clk_a = 0; reg_clk_b = 0;
        en_a = 1; en_b = 0;
        clr_a_n = 1; clr_b_n = 1; #1;
        clr_a_n = 0; clr_b_n = 0; #1; clr_a_n = 1; clr_b_n = 1; #1;
        for (int i = 0; i < 5; i++) tick_a;
        reg_a;
        if (q_a !== 16'd5) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x8154: %0d errors", errors);
        $display("PASS: tb_ttl_74x8154");
        $finish;
    end
endmodule

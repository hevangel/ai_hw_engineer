`timescale 1ns/1ps
module tb_ttl_74x4015;
    logic clk_a, clr_a, sin_a, clk_b, clr_b, sin_b;
    logic [3:0] q_a, q_b;
    ttl_74x4015 dut(.*);
    int errors;
    task tick_a; #1; clk_a = 1; #1; clk_a = 0; endtask
    initial begin
        errors = 0;
        clk_a = 0; clk_b = 0; clr_a = 1; clr_b = 1; sin_a = 0; sin_b = 0; #1;
        clr_a = 0; clr_b = 0; #1;
        sin_a = 1; tick_a; tick_a; tick_a; tick_a;
        if (q_a !== 4'b1111) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x4015: %0d errors", errors);
        $display("PASS: tb_ttl_74x4015");
        $finish;
    end
endmodule

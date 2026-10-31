// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x197;
    logic clk_a, clk_b, clr_n, load_n;
    logic [3:0] d;
    logic q_a, q_b, q_c, q_d;
    ttl_74x197 dut(.clk_a(clk_a), .clk_b(clk_b), .clr_n(clr_n), .load_n(load_n), .d(d), .q_a(q_a), .q_b(q_b), .q_c(q_c), .q_d(q_d));
    task automatic tickA; clk_a=0; #1; clk_a=1; #1; clk_a=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk_a=0; clk_b=0; clr_n=0; load_n=1; d=0; #1;
        clr_n=1; load_n=0; d=4'hF; #1;
        if ({q_d,q_c,q_b,q_a} !== 4'hF) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x197: %0d errors", errors);
        $display("PASS: tb_ttl_74x197");
        $finish;
    end
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x96;
    logic clk, clr_n, pre, din;
    logic [4:0] pre_d, q;
    ttl_74x96 dut(.clk(clk), .clr_n(clr_n), .pre(pre), .pre_d(pre_d), .din(din), .q(q));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; pre=0; pre_d=0; din=0; #1;
        if (q !== 5'b00000) errors++;
        clr_n=1;
        // OR-preset bits 0 and 4
        pre=1; pre_d=5'b10001; #1;
        if (q !== 5'b10001) errors++;
        pre=0;
        // Shift right with din=1: q was 5'b10001, new q = {1, 5'b10001[4:1]} = 5'b11000
        din=1; tick;
        if (q !== 5'b11000) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x96: %0d errors", errors);
        $display("PASS: tb_ttl_74x96");
        $finish;
    end
endmodule

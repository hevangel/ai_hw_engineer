// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x198;
    logic clk, clr_n, s0, s1, din_right, din_left;
    logic [7:0] p, q;
    ttl_74x198 dut(.clk(clk), .clr_n(clr_n), .s0(s0), .s1(s1), .din_right(din_right), .din_left(din_left), .p(p), .q(q));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; s0=0; s1=0; din_right=0; din_left=0; p=8'hA5; #1;
        if (q !== 0) errors++;
        clr_n=1; s0=1; s1=1; tick;
        if (q !== 8'hA5) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x198: %0d errors", errors);
        $display("PASS: tb_ttl_74x198");
        $finish;
    end
endmodule

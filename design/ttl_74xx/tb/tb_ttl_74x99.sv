// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x99;
    logic clk, clr_n, s0, s1, din_right, din_left;
    logic [3:0] p, q;
    ttl_74x99 dut(.clk(clk), .clr_n(clr_n), .s0(s0), .s1(s1),
                  .din_right(din_right), .din_left(din_left), .p(p), .q(q));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; s0=0; s1=0; din_right=0; din_left=0; p=4'hA; #1;
        if (q !== 0) errors++;
        clr_n=1;
        // Parallel load
        s0=1; s1=1; tick;
        if (q !== 4'hA) errors++;
        // Hold
        s0=0; s1=0; p=4'h0; tick;
        if (q !== 4'hA) errors++;
        // Shift right with din_right=1
        s0=1; s1=0; din_right=1; tick;
        if (q !== 4'b1101) errors++;
        // Shift left with din_left=0
        s0=0; s1=1; din_left=0; tick;
        if (q !== 4'b1010) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x99: %0d errors", errors);
        $display("PASS: tb_ttl_74x99");
        $finish;
    end
endmodule

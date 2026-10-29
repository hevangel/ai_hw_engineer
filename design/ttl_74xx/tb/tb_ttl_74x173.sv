// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x173;
    logic clk, clr, oe_n;
    logic [1:0] g_n;
    logic [3:0] d, q;
    ttl_74x173 dut(.clk(clk), .clr(clr), .g_n(g_n), .d(d), .oe_n(oe_n), .q(q));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr=1; g_n=2'b00; d=4'hA; oe_n=0; #1;
        if (q !== 0) errors++;
        clr=0;
        tick; if (q !== 4'hA) errors++;
        g_n[0]=1; d=4'h5; tick; if (q !== 4'hA) errors++; // hold
        g_n[0]=0; tick; if (q !== 4'h5) errors++;
        oe_n=1; #1; if (q !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x173: %0d errors", errors);
        $display("PASS: tb_ttl_74x173");
        $finish;
    end
endmodule

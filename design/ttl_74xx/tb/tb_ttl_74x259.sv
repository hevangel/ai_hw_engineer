// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x259;
    logic g_n, clr_n;
    logic [2:0] a;
    logic d;
    logic [7:0] q;
    ttl_74x259 dut(.g_n(g_n), .clr_n(clr_n), .a(a), .d(d), .q(q));
    int errors;
    initial begin
        errors = 0;
        clr_n=0; g_n=1; a=0; d=0; #1;
        if (q !== 0) errors++;
        clr_n=1; g_n=0;
        a=3'd3; d=1; #1;
        if (q[3] !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x259: %0d errors", errors);
        $display("PASS: tb_ttl_74x259");
        $finish;
    end
endmodule

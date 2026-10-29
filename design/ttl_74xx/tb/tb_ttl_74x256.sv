// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x256;
    logic g_n, clr_n;
    logic [1:0] a, d;
    logic [7:0] q;
    ttl_74x256 dut(.g_n(g_n), .clr_n(clr_n), .a(a), .d(d), .q(q));
    int errors;
    initial begin
        errors = 0;
        clr_n=0; g_n=1; a=0; d=0; #1;
        if (q !== 0) errors++;
        clr_n=1;
        g_n=0; a=2'd1; d=2'b11; #1;
        if (q[1] !== 1 || q[5] !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x256: %0d errors", errors);
        $display("PASS: tb_ttl_74x256");
        $finish;
    end
endmodule

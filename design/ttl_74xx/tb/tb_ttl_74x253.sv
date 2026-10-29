// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x253;
    logic [1:0] s, g_n, y;
    logic [3:0] d0, d1;
    ttl_74x253 dut(.s(s), .g_n(g_n), .d0(d0), .d1(d1), .y(y));
    int errors;
    initial begin
        errors = 0;
        d0=4'b1010; d1=4'b0101; g_n=0; s=2'd0; #1;
        if (y[0] !== d0[0] || y[1] !== d1[0]) errors++;
        g_n=2'b11; #1;
        if (y !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x253: %0d errors", errors);
        $display("PASS: tb_ttl_74x253");
        $finish;
    end
endmodule

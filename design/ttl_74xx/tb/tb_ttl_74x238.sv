// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x238;
    logic [2:0] a;
    logic g1, g2a_n, g2b_n;
    logic [7:0] y;
    ttl_74x238 dut(.a(a), .g1(g1), .g2a_n(g2a_n), .g2b_n(g2b_n), .y(y));
    int errors;
    initial begin
        errors = 0;
        a=3'd5; g1=1; g2a_n=0; g2b_n=0; #1;
        if (y !== 8'b00100000) errors++;
        g1=0; #1;
        if (y !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x238: %0d errors", errors);
        $display("PASS: tb_ttl_74x238");
        $finish;
    end
endmodule

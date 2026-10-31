// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x255;
    logic [1:0] g_n;
    logic [3:0] a;
    logic [7:0] y_n, exp;
    ttl_74x255 dut(.g_n(g_n), .a(a), .y_n(y_n));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 16; i++) begin
            g_n = 2'b00; a = i[3:0]; #1;
            exp = 8'hFF;
            exp[{1'b0, a[1:0]}] = 1'b0;
            exp[{1'b1, a[3:2]}] = 1'b0;
            if (y_n !== exp) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x255: %0d errors", errors);
        $display("PASS: tb_ttl_74x255");
        $finish;
    end
endmodule

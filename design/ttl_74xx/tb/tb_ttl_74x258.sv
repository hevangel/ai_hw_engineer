// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x258;
    logic g_n, select;
    logic [3:0] a, b, y_n;
    ttl_74x258 dut(.g_n(g_n), .select(select), .a(a), .b(b), .y_n(y_n));
    int errors;
    initial begin
        errors = 0;
        a=4'hA; b=4'h5; g_n=0; select=0; #1;
        if (y_n !== ~4'hA) errors++;
        select=1; #1;
        if (y_n !== ~4'h5) errors++;
        g_n=1; #1;
        if (y_n !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x258: %0d errors", errors);
        $display("PASS: tb_ttl_74x258");
        $finish;
    end
endmodule

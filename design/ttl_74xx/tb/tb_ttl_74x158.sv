// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x158;
    logic g_n, select;
    logic [3:0] a, b, y_n, exp;
    ttl_74x158 dut(.g_n(g_n), .select(select), .a(a), .b(b), .y_n(y_n));
    int errors;
    initial begin
        errors = 0;
        a = 4'hA; b = 4'h5;
        for (int i = 0; i < 4; i++) begin
            select = i[0]; g_n = i[1]; #1;
            exp = g_n ? 4'hF : ~(select ? b : a);
            if (y_n !== exp) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x158: %0d errors", errors);
        $display("PASS: tb_ttl_74x158");
        $finish;
    end
endmodule

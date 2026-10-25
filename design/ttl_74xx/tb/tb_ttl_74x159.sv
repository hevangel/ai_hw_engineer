// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x159;
    logic [3:0] a;
    logic g1_n, g2_n;
    logic [15:0] y_n, exp;
    ttl_74x159 dut(.a(a), .g1_n(g1_n), .g2_n(g2_n), .y_n(y_n));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 64; i++) begin
            a = i[3:0]; g1_n = i[4]; g2_n = i[5]; #1;
            exp = 16'hFFFF;
            if (!g1_n && !g2_n) exp[a] = 1'b0;
            if (y_n !== exp) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x159: %0d errors", errors);
        $display("PASS: tb_ttl_74x159");
        $finish;
    end
endmodule

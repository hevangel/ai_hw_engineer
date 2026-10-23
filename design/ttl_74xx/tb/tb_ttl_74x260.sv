// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x260;
    logic [1:0] a, b, c, d, e, y, exp;
    ttl_74x260 dut(.a(a), .b(b), .c(c), .d(d), .e(e), .y(y));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 1024; i++) begin
            a = i[1:0]; b = i[3:2]; c = i[5:4]; d = i[7:6]; e = i[9:8]; #1;
            exp = ~(a | b | c | d | e);
            if (y !== exp) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x260: %0d errors", errors);
        $display("PASS: tb_ttl_74x260");
        $finish;
    end
endmodule

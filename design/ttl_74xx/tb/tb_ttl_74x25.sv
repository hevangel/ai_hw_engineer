// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps

module tb_ttl_74x25;
    logic [1:0] a, b, c, d, g, y, expected;
    ttl_74x25 dut (.a(a), .b(b), .c(c), .d(d), .g(g), .y(y));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 1024; i++) begin
            a = i[1:0]; b = i[3:2]; c = i[5:4]; d = i[7:6]; g = i[9:8]; #1;
            expected[0] = g[0] ? !(a[0] || b[0] || c[0] || d[0]) : 1;
            expected[1] = g[1] ? !(a[1] || b[1] || c[1] || d[1]) : 1;
            if (y !== expected) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x25: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x25 (1024 vectors)");
        $finish;
    end
endmodule

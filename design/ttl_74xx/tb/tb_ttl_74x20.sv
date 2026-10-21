// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps

module tb_ttl_74x20;
    logic [1:0] a, b, c, d, y, expected;
    ttl_74x20 dut (.a(a), .b(b), .c(c), .d(d), .y(y));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 256; i++) begin
            a = i[1:0]; b = i[3:2]; c = i[5:4]; d = i[7:6]; #1;
            expected = ~(a & b & c & d);
            if (y !== expected) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x20: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x20 (256 vectors)");
        $finish;
    end
endmodule

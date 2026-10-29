// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x27;
    logic [2:0] a, b, c, y, expected;
    ttl_74x27 dut (.a(a), .b(b), .c(c), .y(y));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 512; i++) begin
            a = i[2:0]; b = i[5:3]; c = i[8:6]; #1;
            expected = ~(a | b | c);
            if (y !== expected) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x27: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x27 (512 vectors)");
        $finish;
    end
endmodule

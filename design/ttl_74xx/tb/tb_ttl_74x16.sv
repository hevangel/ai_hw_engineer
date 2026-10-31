// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps

module tb_ttl_74x16;
    logic [5:0] a, y, expected;
    ttl_74x16 dut (.a(a), .y(y));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 64; i++) begin
            a = i[5:0]; #1;
            expected = ~a;
            if (y !== expected) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x16: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x16 (64 vectors)");
        $finish;
    end
endmodule

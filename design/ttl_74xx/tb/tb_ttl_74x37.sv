// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x37;
    logic [3:0] a, b, y, expected;
    ttl_74x37 dut (.a(a), .b(b), .y(y));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 256; i++) begin
            a = i[3:0]; b = i[7:4]; #1;
            expected = ~(a & b);
            if (y !== expected) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x37: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x37 (256 vectors)");
        $finish;
    end
endmodule

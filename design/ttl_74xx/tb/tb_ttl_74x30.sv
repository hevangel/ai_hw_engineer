// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x30;
    logic [7:0] a;
    logic y, expected;
    ttl_74x30 dut (.a(a), .y(y));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 256; i++) begin
            a = i[7:0]; #1;
            expected = ~(&a);
            if (y !== expected) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x30: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x30 (256 vectors)");
        $finish;
    end
endmodule

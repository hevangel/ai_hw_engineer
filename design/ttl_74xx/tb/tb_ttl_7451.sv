// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps

module tb_ttl_7451;
    logic [1:0] a1, b1, a2, b2, y, expected;
    ttl_7451 dut (.a1(a1), .b1(b1), .a2(a2), .b2(b2), .y(y));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 256; i++) begin
            a1 = i[1:0]; b1 = i[3:2]; a2 = i[5:4]; b2 = i[7:6]; #1;
            expected = ~((a1 & b1) | (a2 & b2));
            if (y !== expected) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_7451: %0d mismatches", errors);
        $display("PASS: tb_ttl_7451 (256 vectors)");
        $finish;
    end
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps

module tb_ttl_74x45;
    logic [3:0] bcd;
    logic [9:0] y_n, expected;
    ttl_74x45 dut (.bcd(bcd), .y_n(y_n));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 16; i++) begin
            bcd = i[3:0]; #1;
            expected = 10'b1111111111;
            if (i < 10) expected[i] = 1'b0;
            if (y_n !== expected) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x45: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x45 (16 vectors)");
        $finish;
    end
endmodule

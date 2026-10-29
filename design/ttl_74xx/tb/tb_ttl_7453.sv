// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps

module tb_ttl_7453;
    logic x;
    logic a1, b1, a2, b2, a3, b3, a4, b4;
    logic y, expected;
    ttl_7453 dut (.x(x),
        .a1(a1), .b1(b1),
        .a2(a2), .b2(b2),
        .a3(a3), .b3(b3),
        .a4(a4), .b4(b4),
        .y(y)
    );
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 512; i++) begin
            x=i[8];
            {b4,a4,b3,a3,b2,a2,b1,a1} = i[7:0]; #1;
            expected = ~((a1 & b1) | (a2 & b2) | (a3 & b3) | (a4 & b4));
            expected &= ~x;
            if (y !== expected) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_7453: %0d mismatches", errors);
        $display("PASS: tb_ttl_7453 (512 vectors including expansion)");
        $finish;
    end
endmodule

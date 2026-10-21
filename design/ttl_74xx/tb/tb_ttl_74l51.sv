// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps

module tb_ttl_74l51;
    logic a3, b3, c3, d3, e3, f3;
    logic a2, b2, c2, d2;
    logic [1:0] y, expected;
    ttl_74l51 dut (
        .a3(a3), .b3(b3), .c3(c3), .d3(d3), .e3(e3), .f3(f3),
        .a2(a2), .b2(b2), .c2(c2), .d2(d2),
        .y(y)
    );
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 1024; i++) begin
            {f3,e3,d3,c3,b3,a3} = i[5:0];
            {d2,c2,b2,a2} = i[9:6];
            #1;
            expected[0] = ~((a3 & b3 & c3) | (d3 & e3 & f3));
            expected[1] = ~((a2 & b2) | (c2 & d2));
            if (y !== expected) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74l51: %0d mismatches", errors);
        $display("PASS: tb_ttl_74l51 (1024 vectors)");
        $finish;
    end
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x139;
    logic [1:0] g_n;
    logic [3:0] a;
    logic [7:0] y_n, expected;
    ttl_74x139 dut (.g_n(g_n), .a(a), .y_n(y_n));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 64; i++) begin
            g_n = i[1:0];
            a   = i[5:2];
            #1;
            expected = 8'hFF;
            if (!g_n[0]) expected[{1'b0, a[1:0]}] = 1'b0;
            if (!g_n[1]) expected[{1'b1, a[3:2]}] = 1'b0;
            if (y_n !== expected) begin
                $display("FAIL g_n=%b a=%b y_n=%b exp=%b", g_n, a, y_n, expected);
                errors++;
            end
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x139: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x139 (64 vectors)");
        $finish;
    end
endmodule

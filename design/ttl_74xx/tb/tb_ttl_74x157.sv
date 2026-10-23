// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x157;
    logic g_n, select;
    logic [3:0] a, b, y, expected;
    ttl_74x157 dut (.g_n(g_n), .select(select), .a(a), .b(b), .y(y));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 256; i++) begin
            g_n = i[0]; select = i[1];
            a = i[5:2]; b = {i[7:6], i[5:4]};
            #1;
            expected = g_n ? 4'h0 : (select ? b : a);
            if (y !== expected) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x157: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x157 (256 vectors)");
        $finish;
    end
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x61;
    logic [2:0] a, b, c, x, x_n;
    ttl_74x61 dut(.a(a),.b(b),.c(c),.x(x),.x_n(x_n));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 512; i++) begin
            a = i[2:0]; b = i[5:3]; c = i[8:6]; #1;
            if (x !== (a&b&c) || x_n !== ~(a&b&c)) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x61: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x61 (512 vectors)");
        $finish;
    end
endmodule

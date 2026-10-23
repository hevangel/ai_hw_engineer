// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x60;
    logic [3:0] a1, a2;
    logic x1, x1_n, x2, x2_n;
    ttl_74x60 dut(.a1(a1),.a2(a2),.x1(x1),.x1_n(x1_n),.x2(x2),.x2_n(x2_n));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 256; i++) begin
            a1 = i[3:0]; a2 = i[7:4]; #1;
            if (x1 !== (&a1) || x1_n !== ~(&a1)) errors++;
            if (x2 !== (&a2) || x2_n !== ~(&a2)) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x60: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x60 (256 vectors)");
        $finish;
    end
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x82;
    logic [1:0] a, b, s, exp_s;
    logic c0, c2, exp_c2;
    logic [2:0] full;
    ttl_74x82 dut(.a(a), .b(b), .c0(c0), .s(s), .c2(c2));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 32; i++) begin
            a = i[1:0]; b = i[3:2]; c0 = i[4]; #1;
            full = {1'b0, a} + {1'b0, b} + {2'b0, c0};
            exp_s = full[1:0]; exp_c2 = full[2];
            if (s !== exp_s || c2 !== exp_c2) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x82: %0d errors", errors);
        $display("PASS: tb_ttl_74x82 (32 vectors)");
        $finish;
    end
endmodule

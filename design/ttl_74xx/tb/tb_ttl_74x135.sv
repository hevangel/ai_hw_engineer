// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x135;
    logic [3:0] a, b, y, exp;
    logic [1:0] c;
    ttl_74x135 dut(.a(a), .b(b), .c(c), .y(y));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 1024; i++) begin
            a = i[3:0]; b = i[7:4]; c = i[9:8]; #1;
            exp[0] = a[0] ^ b[0] ^ c[0];
            exp[1] = a[1] ^ b[1] ^ c[0];
            exp[2] = a[2] ^ b[2] ^ c[1];
            exp[3] = a[3] ^ b[3] ^ c[1];
            if (y !== exp) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x135: %0d errors", errors);
        $display("PASS: tb_ttl_74x135 (1024 vectors)");
        $finish;
    end
endmodule

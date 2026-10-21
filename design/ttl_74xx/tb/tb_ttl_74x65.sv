// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x65;
    logic a1,b1,c1,d1,a2,b2,c2,a3,b3,a4,b4,y,exp;
    ttl_74x65 dut(.a1(a1),.b1(b1),.c1(c1),.d1(d1),.a2(a2),.b2(b2),.c2(c2),.a3(a3),.b3(b3),.a4(a4),.b4(b4),.y(y));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 2048; i++) begin
            {b4,a4,b3,a3,c2,b2,a2,d1,c1,b1,a1} = i[10:0]; #1;
            exp = ~((a1&b1&c1&d1) | (a2&b2&c2) | (a3&b3) | (a4&b4));
            if (y !== exp) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x65: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x65 (2048 vectors)");
        $finish;
    end
endmodule

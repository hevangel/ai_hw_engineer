// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x58;
    logic a1,b1,c1,a2,b2,c2,d1,e1,d2,e2;
    logic [1:0] y, exp;
    ttl_74x58 dut(.a1(a1),.b1(b1),.c1(c1),.a2(a2),.b2(b2),.c2(c2),.d1(d1),.e1(e1),.d2(d2),.e2(e2),.y(y));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 1024; i++) begin
            {e2,d2,e1,d1,c2,b2,a2,c1,b1,a1} = i[9:0]; #1;
            exp[0] = (a1&b1&c1) | (a2&b2&c2);
            exp[1] = (d1&e1) | (d2&e2);
            if (y !== exp) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x58: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x58 (1024 vectors)");
        $finish;
    end
endmodule

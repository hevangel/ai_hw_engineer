// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x59;
    logic [1:0] a3,b3,c3,a2,b2,y,exp;
    ttl_74x59 dut(.a3(a3),.b3(b3),.c3(c3),.a2(a2),.b2(b2),.y(y));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 1024; i++) begin
            {b2,a2,c3,b3,a3} = i[9:0]; #1;
            exp = ~((a3 & b3 & c3) | (a2 & b2));
            if (y !== exp) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x59: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x59 (1024 vectors)");
        $finish;
    end
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x134;
    logic [11:0] a;
    logic oe_n, y, exp;
    ttl_74x134 dut(.a(a), .oe_n(oe_n), .y(y));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 100; i++) begin
            a = 12'($random); oe_n = i[0]; #1;
            exp = oe_n ? 1'b0 : ~(&a);
            if (y !== exp) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x134: %0d errors", errors);
        $display("PASS: tb_ttl_74x134");
        $finish;
    end
endmodule

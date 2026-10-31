// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x126;
    logic [3:0] a, oe, y, exp;
    ttl_74x126 dut(.a(a), .oe(oe), .y(y));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 256; i++) begin
            a = i[3:0]; oe = i[7:4]; #1;
            for (int j = 0; j < 4; j++) exp[j] = oe[j] ? a[j] : 1'b0;
            if (y !== exp) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x126: %0d errors", errors);
        $display("PASS: tb_ttl_74x126 (256 vectors)");
        $finish;
    end
endmodule

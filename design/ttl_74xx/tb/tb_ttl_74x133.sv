// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x133;
    logic [12:0] a;
    logic y, exp;
    ttl_74x133 dut(.a(a), .y(y));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 8192; i++) begin
            a = i[12:0]; #1;
            exp = ~(&a);
            if (y !== exp) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x133: %0d errors", errors);
        $display("PASS: tb_ttl_74x133 (8192 vectors)");
        $finish;
    end
endmodule

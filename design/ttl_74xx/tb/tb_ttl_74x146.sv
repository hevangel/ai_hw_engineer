// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x146;
    logic [2:0] a;
    logic en_n;
    logic [7:0] y_n, exp;
    ttl_74x146 dut(.a(a), .en_n(en_n), .y_n(y_n));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 16; i++) begin
            a = i[2:0]; en_n = i[3]; #1;
            exp = 8'hFF;
            if (!en_n) exp[a] = 1'b0;
            if (y_n !== exp) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x146: %0d errors", errors);
        $display("PASS: tb_ttl_74x146");
        $finish;
    end
endmodule

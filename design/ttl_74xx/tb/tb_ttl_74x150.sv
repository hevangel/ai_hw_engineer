// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x150;
    logic g_n;
    logic [3:0] s;
    logic [15:0] d;
    logic y_n;
    ttl_74x150 dut(.g_n(g_n), .s(s), .d(d), .y_n(y_n));
    int errors;
    initial begin
        errors = 0;
        d = 16'h5A5A; g_n = 0;
        for (int i = 0; i < 16; i++) begin
            s = i[3:0]; #1;
            if (y_n !== ~d[s]) errors++;
        end
        g_n = 1; #1;
        if (y_n !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x150: %0d errors", errors);
        $display("PASS: tb_ttl_74x150");
        $finish;
    end
endmodule

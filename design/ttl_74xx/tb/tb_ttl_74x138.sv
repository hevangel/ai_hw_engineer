// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps

module tb_ttl_74x138;
    logic [2:0] a;
    logic g1, g2a_n, g2b_n;
    logic [7:0] y_n, exp_y_n;

    ttl_74x138 dut (.a(a), .g1(g1), .g2a_n(g2a_n), .g2b_n(g2b_n), .y_n(y_n));

    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 64; i++) begin
            a     = i[2:0];
            g1    = i[3];
            g2a_n = i[4];
            g2b_n = i[5];
            #1;
            exp_y_n = 8'hFF;
            if (g1 && !g2a_n && !g2b_n) exp_y_n[a] = 1'b0;
            if (y_n !== exp_y_n) begin
                $display("FAIL a=%d g1=%b g2a_n=%b g2b_n=%b y_n=%b exp=%b",
                         a, g1, g2a_n, g2b_n, y_n, exp_y_n);
                errors++;
            end
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x138: %0d errors", errors);
        $display("PASS: tb_ttl_74x138 (64 vectors)");
        $finish;
    end
endmodule

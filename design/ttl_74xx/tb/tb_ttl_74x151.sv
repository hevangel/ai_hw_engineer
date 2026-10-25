// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x151;
    logic g_n;
    logic [2:0] s;
    logic [7:0] d;
    logic y, w, exp_y, exp_w;
    ttl_74x151 dut (.g_n(g_n), .s(s), .d(d), .y(y), .w(w));
    int errors;
    initial begin
        errors = 0;
        // Walk every select with several data patterns
        for (int dp = 0; dp < 16; dp++) begin
            d = 8'($random);
            for (int ss = 0; ss < 8; ss++) begin
                s = ss[2:0];
                // Enabled
                g_n = 0; #1;
                exp_y = d[s]; exp_w = ~exp_y;
                if (y !== exp_y || w !== exp_w) errors++;
                // Disabled
                g_n = 1; #1;
                if (y !== 1'b0 || w !== 1'b1) errors++;
            end
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x151: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x151");
        $finish;
    end
endmodule

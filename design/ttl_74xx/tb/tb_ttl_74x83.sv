// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps

module tb_ttl_74x83;
    logic [3:0] a, b, sum, exp_sum;
    logic c0, c4, exp_c4;
    logic [4:0] full;

    ttl_74x83 dut (.a(a), .b(b), .c0(c0), .sum(sum), .c4(c4));

    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 512; i++) begin
            a  = i[3:0];
            b  = i[7:4];
            c0 = i[8];
            #1;
            full = {1'b0, a} + {1'b0, b} + {4'b0, c0};
            exp_sum = full[3:0];
            exp_c4  = full[4];
            if (sum !== exp_sum || c4 !== exp_c4) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x83: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x83 (512 vectors)");
        $finish;
    end
endmodule

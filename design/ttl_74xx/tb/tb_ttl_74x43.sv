// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps

module tb_ttl_74x43;
    logic [3:0] xs3;
    logic [9:0] y_n, expected;
    ttl_74x43 dut (.xs3(xs3), .y_n(y_n));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 16; i++) begin
            xs3 = i[3:0]; #1;
            expected = 10'b1111111111;
            if (i >= 3 && i <= 12) expected[i - 3] = 1'b0;
            if (y_n !== expected) begin
                $display("FAIL xs3=%d y_n=%b expected=%b", i, y_n, expected);
                errors++;
            end
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x43: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x43 (16 vectors)");
        $finish;
    end
endmodule

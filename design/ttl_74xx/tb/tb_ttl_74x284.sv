// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x284;
    logic [3:0] a, b, y_hi;
    ttl_74x284 dut(.a(a), .b(b), .y_hi(y_hi));
    logic [7:0] expected;
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 16; i++) for (int j = 0; j < 16; j++) begin
            a = i[3:0]; b = j[3:0]; #1;
            expected = 8'(i * j);
            if (y_hi !== expected[7:4]) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x284: %0d errors", errors);
        $display("PASS: tb_ttl_74x284");
        $finish;
    end
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x80;
    logic a1, a2, b1, b2, c_in_n, sum, sum_n, c_out;
    ttl_74x80 dut(.a1(a1), .a2(a2), .b1(b1), .b2(b2), .c_in_n(c_in_n),
                  .sum(sum), .sum_n(sum_n), .c_out(c_out));
    logic ea, eb, ec_in;
    logic [1:0] er;
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 32; i++) begin
            a1 = i[0]; a2 = i[1]; b1 = i[2]; b2 = i[3]; c_in_n = i[4]; #1;
            ea    = a1 & a2;
            eb    = b1 & b2;
            ec_in = ~c_in_n;
            er    = ea + eb + ec_in;
            if (sum !== er[0] || sum_n !== ~er[0] || c_out !== er[1]) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x80: %0d errors", errors);
        $display("PASS: tb_ttl_74x80 (32 vectors)");
        $finish;
    end
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x183;
    logic [1:0] a, b, cin, s, c_out;
    ttl_74x183 dut(.a(a), .b(b), .cin(cin), .s(s), .c_out(c_out));
    int errors;
    logic [1:0] expected;
    initial begin
        errors = 0;
        for (int i = 0; i < 64; i++) begin
            a = i[1:0]; b = i[3:2]; cin = i[5:4]; #1;
            for (int j = 0; j < 2; j++) begin
                expected = {1'b0, a[j]} + {1'b0, b[j]} + {1'b0, cin[j]};
                if (s[j] !== expected[0] || c_out[j] !== expected[1]) errors++;
            end
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x183: %0d errors", errors);
        $display("PASS: tb_ttl_74x183");
        $finish;
    end
endmodule

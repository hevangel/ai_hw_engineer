// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x274;
    logic [3:0] a, b;
    logic [7:0] y;
    ttl_74x274 dut(.a(a), .b(b), .y(y));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 16; i++) for (int j = 0; j < 16; j++) begin
            a = i[3:0]; b = j[3:0]; #1;
            if (y !== 8'(i * j)) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x274: %0d errors", errors);
        $display("PASS: tb_ttl_74x274");
        $finish;
    end
endmodule

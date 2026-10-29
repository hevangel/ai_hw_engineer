// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x261;
    logic [1:0] a;
    logic [3:0] b;
    logic [5:0] y;
    ttl_74x261 dut(.a(a), .b(b), .y(y));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 16; j++) begin
                a = i[1:0]; b = j[3:0]; #1;
                if (y !== 6'(i * j)) errors++;
            end
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x261: %0d errors", errors);
        $display("PASS: tb_ttl_74x261");
        $finish;
    end
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x265;
    logic [3:0] a, y, y_n;
    ttl_74x265 dut(.a(a), .y(y), .y_n(y_n));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 16; i++) begin
            a = i[3:0]; #1;
            if (y !== a || y_n !== ~a) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x265: %0d errors", errors);
        $display("PASS: tb_ttl_74x265");
        $finish;
    end
endmodule

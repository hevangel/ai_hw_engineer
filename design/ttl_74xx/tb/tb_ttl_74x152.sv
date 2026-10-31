// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x152;
    logic [2:0] s;
    logic [7:0] d;
    logic y_n;
    ttl_74x152 dut(.s(s), .d(d), .y_n(y_n));
    int errors;
    initial begin
        errors = 0;
        d = 8'h5A;
        for (int i = 0; i < 8; i++) begin
            s = i[2:0]; #1;
            if (y_n !== ~d[s]) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x152: %0d errors", errors);
        $display("PASS: tb_ttl_74x152");
        $finish;
    end
endmodule

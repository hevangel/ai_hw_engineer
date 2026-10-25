// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x241;
    logic [7:0] a, y;
    logic oe1_n, oe2;
    ttl_74x241 dut(.a(a), .oe1_n(oe1_n), .oe2(oe2), .y(y));
    int errors;
    initial begin
        errors = 0;
        a=8'hA5; oe1_n=0; oe2=1; #1;
        if (y !== 8'hA5) errors++;
        oe1_n=1; oe2=0; #1;
        if (y !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x241: %0d errors", errors);
        $display("PASS: tb_ttl_74x241");
        $finish;
    end
endmodule

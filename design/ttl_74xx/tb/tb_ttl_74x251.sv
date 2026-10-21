// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x251;
    logic g_n;
    logic [2:0] s;
    logic [7:0] d;
    logic y, y_n;
    ttl_74x251 dut(.g_n(g_n), .s(s), .d(d), .y(y), .y_n(y_n));
    int errors;
    initial begin
        errors = 0;
        d=8'b10101010; g_n=0; s=3'd0; #1;
        if (y !== d[0] || y_n !== ~d[0]) errors++;
        g_n=1; #1;
        if (y !== 0 || y_n !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x251: %0d errors", errors);
        $display("PASS: tb_ttl_74x251");
        $finish;
    end
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x110;
    logic clk, j1, j2, j3, k1, k2, k3, clr_n, pre_n, q, q_n;
    ttl_74x110 dut(.clk(clk), .j1(j1), .j2(j2), .j3(j3), .k1(k1), .k2(k2), .k3(k3),
                   .clr_n(clr_n), .pre_n(pre_n), .q(q), .q_n(q_n));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; pre_n=1; j1=0; j2=0; j3=0; k1=0; k2=0; k3=0; #1;
        if (q !== 0) errors++; clr_n=1;
        j1=1; j2=1; j3=1; tick; if (q !== 1) errors++;
        j1=0; j2=0; j3=0; k1=1; k2=1; k3=1; tick; if (q !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x110: %0d errors", errors);
        $display("PASS: tb_ttl_74x110");
        $finish;
    end
endmodule

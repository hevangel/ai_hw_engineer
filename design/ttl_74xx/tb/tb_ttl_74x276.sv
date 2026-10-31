// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x276;
    logic [3:0] clk, j, k_n, q;
    logic clr_n, pre_n;
    ttl_74x276 dut(.clk(clk), .clr_n(clr_n), .pre_n(pre_n), .j(j), .k_n(k_n), .q(q));
    task automatic tick(input int i); clk[i]=0; #1; clk[i]=1; #1; clk[i]=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; pre_n=1; j=0; k_n=4'hF; #1;
        if (q !== 0) errors++; clr_n=1;
        j=4'hF; k_n=4'hF; tick(0); tick(1); tick(2); tick(3);
        if (q !== 4'hF) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x276: %0d errors", errors);
        $display("PASS: tb_ttl_74x276");
        $finish;
    end
endmodule

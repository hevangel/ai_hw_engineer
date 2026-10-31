// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x73;
    logic [1:0] clk, j, k, clr_n, q, q_n;
    ttl_74x73 dut(.clk(clk), .j(j), .k(k), .clr_n(clr_n), .q(q), .q_n(q_n));
    task automatic tick(input int i); clk[i]=0; #1; clk[i]=1; #1; clk[i]=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clr_n = 0; clk = 0; j = 0; k = 0; #1;
        if (q !== 0) errors++; clr_n = 2'b11;
        j = 2'b11; k = 2'b00; tick(0); tick(1);
        if (q !== 2'b11) errors++;
        j = 2'b11; k = 2'b11; tick(0); tick(1);
        if (q !== 2'b00) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x73: %0d errors", errors);
        $display("PASS: tb_ttl_74x73");
        $finish;
    end
endmodule

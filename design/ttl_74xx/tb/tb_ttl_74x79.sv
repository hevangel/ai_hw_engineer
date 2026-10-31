// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x79;
    logic [1:0] clk, d, clr_n, pre_n, q, q_n;
    ttl_74x79 dut(.clk(clk), .d(d), .clr_n(clr_n), .pre_n(pre_n), .q(q), .q_n(q_n));
    task automatic tick(input int i); clk[i]=0; #1; clk[i]=1; #1; clk[i]=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clr_n = 0; pre_n = 2'b11; clk = 0; d = 0; #1;
        if (q !== 0) errors++; clr_n = 2'b11;
        d = 2'b11; tick(0); tick(1); if (q !== 2'b11) errors++;
        d = 2'b00; tick(0); tick(1); if (q !== 2'b00) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x79: %0d errors", errors);
        $display("PASS: tb_ttl_74x79");
        $finish;
    end
endmodule

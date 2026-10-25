// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x72;
    logic clk, j, k, clr_n, pre_n, q, q_n;
    ttl_74x72 dut(.clk(clk), .j(j), .k(k), .clr_n(clr_n), .pre_n(pre_n), .q(q), .q_n(q_n));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clr_n = 0; pre_n = 1; clk = 0; j = 0; k = 0; #1;
        if (q !== 0) errors++; clr_n = 1;
        j=1; k=0; tick; if (q !== 1) errors++;
        j=0; k=1; tick; if (q !== 0) errors++;
        j=1; k=1; tick; if (q !== 1) errors++;
        tick; if (q !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x72: %0d errors", errors);
        $display("PASS: tb_ttl_74x72");
        $finish;
    end
endmodule

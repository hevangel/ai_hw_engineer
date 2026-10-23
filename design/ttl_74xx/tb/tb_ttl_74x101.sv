// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x101;
    logic clk, j1a,j1b,j2a,j2b,k1a,k1b,k2a,k2b, pre_n, q, q_n;
    ttl_74x101 dut(.clk(clk), .j1a(j1a), .j1b(j1b), .j2a(j2a), .j2b(j2b),
                   .k1a(k1a), .k1b(k1b), .k2a(k2a), .k2b(k2b),
                   .pre_n(pre_n), .q(q), .q_n(q_n));
    task automatic ntick; clk=1; #1; clk=0; #1; clk=1; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=1; pre_n=1; j1a=0; j1b=0; j2a=0; j2b=0; k1a=0; k1b=0; k2a=0; k2b=0; #1;
        pre_n=0; #1; if (q !== 1) errors++;
        pre_n=1;
        j1a=1; j1b=1; ntick; if (q !== 1) errors++;
        j1a=0; j1b=0; k2a=1; k2b=1; ntick; if (q !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x101: %0d errors", errors);
        $display("PASS: tb_ttl_74x101");
        $finish;
    end
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x104;
    logic clk, j, k, q, q_n;
    ttl_74x104 dut(.clk(clk), .j(j), .k(k), .q(q), .q_n(q_n));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk = 0; j = 0; k = 1; tick;  // reset
        if (q !== 0) errors++;
        j = 1; k = 0; tick;  // set
        if (q !== 1) errors++;
        j = 1; k = 1; tick;  // toggle
        if (q !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x104: %0d errors", errors);
        $display("PASS: tb_ttl_74x104");
        $finish;
    end
endmodule

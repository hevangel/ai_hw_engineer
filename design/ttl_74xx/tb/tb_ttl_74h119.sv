// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74h119;
    logic clk, clr_n;
    logic [1:0] j, k, q, q_n;
    ttl_74h119 dut(.clk(clk), .clr_n(clr_n), .j(j), .k(k), .q(q), .q_n(q_n));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; j=0; k=0; #1;
        if (q !== 0) errors++; clr_n=1;
        j=2'b11; tick; if (q !== 2'b11) errors++;
        k=2'b11; tick; if (q !== 2'b00) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74h119: %0d errors", errors);
        $display("PASS: tb_ttl_74h119");
        $finish;
    end
endmodule

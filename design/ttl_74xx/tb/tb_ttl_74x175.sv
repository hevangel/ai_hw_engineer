// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x175;
    logic clk, clr_n;
    logic [3:0] d, q, q_n;
    ttl_74x175 dut(.clk(clk), .clr_n(clr_n), .d(d), .q(q), .q_n(q_n));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; d=4'hF; #1;
        if (q !== 0) errors++;
        clr_n=1; tick;
        if (q !== 4'hF || q_n !== 4'h0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x175: %0d errors", errors);
        $display("PASS: tb_ttl_74x175");
        $finish;
    end
endmodule

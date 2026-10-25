// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x95;
    logic clk, mode, din;
    logic [3:0] p, q;
    ttl_74x95 dut(.clk(clk), .mode(mode), .din(din), .p(p), .q(q));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; mode=1; p=4'hA; din=0; tick;
        if (q !== 4'hA) errors++;
        // Shift right with din=1: q=4'hA=4'b1010, new q = {1, 4'b1010[3:1]} = 4'b1101
        mode=0; din=1; tick;
        if (q !== 4'b1101) errors++;
        // Another shift right with din=0: new q = {0, 4'b1101[3:1]} = 4'b0110
        din=0; tick;
        if (q !== 4'b0110) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x95: %0d errors", errors);
        $display("PASS: tb_ttl_74x95");
        $finish;
    end
endmodule

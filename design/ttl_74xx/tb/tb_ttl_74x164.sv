// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x164;
    logic clk, clr_n, a, b;
    logic [7:0] q;
    ttl_74x164 dut(.clk(clk), .clr_n(clr_n), .a(a), .b(b), .q(q));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; a=1; b=1; #1;
        if (q !== 0) errors++;
        clr_n=1;
        tick; tick; tick;
        if (q !== 8'h07) errors++;
        a = 0;
        tick; tick; tick; tick; tick;
        if (q !== 8'b11100000) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x164: %0d errors", errors);
        $display("PASS: tb_ttl_74x164");
        $finish;
    end
endmodule

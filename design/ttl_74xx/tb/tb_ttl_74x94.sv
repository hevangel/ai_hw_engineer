// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x94;
    logic clk, din, pa, pb;
    logic [3:0] pre_a, pre_b, q;
    ttl_74x94 dut(.clk(clk), .din(din), .pa(pa), .pb(pb), .pre_a(pre_a), .pre_b(pre_b), .q(q));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; din=0; pa=0; pb=0; pre_a=4'hA; pre_b=4'h5; #1;
        // Preset A
        pa=1; #1; if (q !== 4'hA) errors++;
        pa=0; #1;
        // Shift left in 1: q was 4'hA = 4'b1010, then {q[2:0], 1} = 4'b0101 = 4'h5
        din=1; tick;
        if (q !== 4'b0101) errors++;
        // Preset B
        pb=1; #1; if (q !== 4'h5) errors++;
        pb=0; #1;
        if (errors != 0) $fatal(1, "tb_ttl_74x94: %0d errors", errors);
        $display("PASS: tb_ttl_74x94");
        $finish;
    end
endmodule

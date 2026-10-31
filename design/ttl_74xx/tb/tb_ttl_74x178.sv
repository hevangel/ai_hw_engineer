// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x178;
    logic clk, s_l, shift_en, din;
    logic [3:0] p, q;
    ttl_74x178 dut(.clk(clk), .s_l(s_l), .shift_en(shift_en), .din(din), .p(p), .q(q));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; s_l=1; shift_en=0; din=0; p=4'hA; tick;
        if (q !== 4'hA) errors++;
        s_l=0; shift_en=1; din=1; tick;
        if (q !== 4'b1101) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x178: %0d errors", errors);
        $display("PASS: tb_ttl_74x178");
        $finish;
    end
endmodule

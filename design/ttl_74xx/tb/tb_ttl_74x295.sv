// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x295;
    logic clk, oe_n, s_l, dir, din;
    logic [3:0] p, q;
    ttl_74x295 dut(.clk(clk), .oe_n(oe_n), .s_l(s_l), .dir(dir), .din(din), .p(p), .q(q));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; oe_n=0; s_l=1; dir=0; din=0; p=4'hA; tick;
        if (q !== 4'hA) errors++;
        s_l=0; dir=1; din=1; tick;
        if (q !== 4'b0101) errors++;
        oe_n=1; #1;
        if (q !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x295: %0d errors", errors);
        $display("PASS: tb_ttl_74x295");
        $finish;
    end
endmodule

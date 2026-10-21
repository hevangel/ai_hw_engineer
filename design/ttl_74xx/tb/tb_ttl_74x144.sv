// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x144;
    logic clk, clr_n, le, c_n;
    logic [6:0] seg;
    ttl_74x144 dut(.clk(clk), .clr_n(clr_n), .le(le), .seg(seg), .c_n(c_n));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk = 0; clr_n = 0; le = 1; #1;
        if (seg !== 7'b1111110) errors++;
        clr_n = 1; tick;
        if (seg !== 7'b0110000) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x144: %0d errors", errors);
        $display("PASS: tb_ttl_74x144");
        $finish;
    end
endmodule

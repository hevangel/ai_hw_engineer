// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x142;
    logic clk, clr_n, le, c_n;
    logic [9:0] y_n;
    ttl_74x142 dut(.clk(clk), .clr_n(clr_n), .le(le), .y_n(y_n), .c_n(c_n));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk = 0; clr_n = 0; le = 1; #1;
        if (y_n !== 10'b1111111110) errors++;  // latched 0 -> y_n[0]=0
        clr_n = 1;
        tick;
        if (y_n[1] !== 1'b0) errors++;
        // Count to 9
        for (int i = 0; i < 8; i++) tick;
        if (y_n[9] !== 1'b0) errors++;
        if (c_n !== 1'b0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x142: %0d errors", errors);
        $display("PASS: tb_ttl_74x142");
        $finish;
    end
endmodule

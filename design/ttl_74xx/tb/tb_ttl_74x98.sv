// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x98;
    logic clk, clr_n, select;
    logic [3:0] a, b, q;
    ttl_74x98 dut(.clk(clk), .clr_n(clr_n), .select(select), .a(a), .b(b), .q(q));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; select=0; a=4'h5; b=4'hA; #1;
        if (q !== 0) errors++;
        clr_n=1;
        tick; if (q !== a) errors++;
        select=1; tick; if (q !== b) errors++;
        clr_n=0; #1; if (q !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x98: %0d errors", errors);
        $display("PASS: tb_ttl_74x98");
        $finish;
    end
endmodule

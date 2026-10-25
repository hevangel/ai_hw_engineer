// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x226;
    logic clk, dir, oe_n;
    logic [3:0] a_in, b_in, a_out, b_out;
    logic a_oe_n, b_oe_n;
    ttl_74x226 dut(.clk(clk), .dir(dir), .oe_n(oe_n), .a_in(a_in), .b_in(b_in), .a_out(a_out), .b_out(b_out), .a_oe_n(a_oe_n), .b_oe_n(b_oe_n));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; dir=1; oe_n=0; a_in=4'hA; b_in=0; tick;
        if (b_out !== 4'hA) errors++;
        dir=0; b_in=4'h5; tick;
        if (a_out !== 4'h5) errors++;
        oe_n=1; #1;
        if (a_out !== 0 || b_out !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x226: %0d errors", errors);
        $display("PASS: tb_ttl_74x226");
        $finish;
    end
endmodule

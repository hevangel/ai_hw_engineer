// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x195;
    logic clk, clr_n, sh_ld_n, j, k_n, q3_n;
    logic [3:0] p, q;
    ttl_74x195 dut(.clk(clk), .clr_n(clr_n), .sh_ld_n(sh_ld_n), .j(j), .k_n(k_n), .p(p), .q(q), .q3_n(q3_n));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; sh_ld_n=1; j=0; k_n=1; p=0; #1;
        if (q !== 0) errors++;
        clr_n=1;
        sh_ld_n=0; p=4'hF; tick;
        if (q !== 4'hF) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x195: %0d errors", errors);
        $display("PASS: tb_ttl_74x195");
        $finish;
    end
endmodule

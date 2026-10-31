// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x199;
    logic clk, clr_n, sh_ld_n, j, k_n;
    logic [7:0] p, q;
    ttl_74x199 dut(.clk(clk), .clr_n(clr_n), .sh_ld_n(sh_ld_n), .j(j), .k_n(k_n), .p(p), .q(q));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; sh_ld_n=0; j=0; k_n=1; p=8'h0F; #1;
        if (q !== 0) errors++;
        clr_n=1; tick;
        if (q !== 8'h0F) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x199: %0d errors", errors);
        $display("PASS: tb_ttl_74x199");
        $finish;
    end
endmodule

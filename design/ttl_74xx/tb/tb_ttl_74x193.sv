// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x193;
    logic sys_clk, clk_up, clk_dn, clr, load_n;
    logic [3:0] d, q;
    logic co_n, bo_n;
    ttl_74x193 dut(.sys_clk(sys_clk), .clk_up(clk_up), .clk_dn(clk_dn), .clr(clr), .load_n(load_n), .d(d), .q(q), .co_n(co_n), .bo_n(bo_n));
    task automatic clk_tick; sys_clk=0; #1; sys_clk=1; #1; sys_clk=0; #1; endtask
    task automatic pulse_up; clk_up=1; clk_tick; clk_up=0; clk_tick; endtask
    int errors;
    initial begin
        errors = 0;
        sys_clk=0; clk_up=0; clk_dn=0; clr=1; load_n=1; d=0; clk_tick;
        clr=0;
        for (int i = 0; i < 16; i++) begin
            if (q !== i[3:0]) errors++;
            pulse_up;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x193: %0d errors", errors);
        $display("PASS: tb_ttl_74x193");
        $finish;
    end
endmodule

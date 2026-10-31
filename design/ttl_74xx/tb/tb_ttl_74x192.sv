// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x192;
    logic sys_clk, clk_up, clk_dn, clr, load_n;
    logic [3:0] d, q;
    logic co_n, bo_n;
    ttl_74x192 dut(.sys_clk(sys_clk), .clk_up(clk_up), .clk_dn(clk_dn), .clr(clr), .load_n(load_n), .d(d), .q(q), .co_n(co_n), .bo_n(bo_n));
    task automatic clk_tick; sys_clk=0; #1; sys_clk=1; #1; sys_clk=0; #1; endtask
    task automatic pulse_up; clk_up=1; clk_tick; clk_up=0; clk_tick; endtask
    task automatic pulse_dn; clk_dn=1; clk_tick; clk_dn=0; clk_tick; endtask
    int errors;
    initial begin
        errors = 0;
        sys_clk=0; clk_up=0; clk_dn=0; clr=1; load_n=1; d=0; clk_tick;
        if (q !== 0) errors++;
        clr=0;
        pulse_up; if (q !== 1) errors++;
        pulse_up; if (q !== 2) errors++;
        pulse_dn; if (q !== 1) errors++;
        load_n=0; d=4'd9; clk_tick;
        if (q !== 9) errors++;
        load_n=1;
        if (errors != 0) $fatal(1, "tb_ttl_74x192: %0d errors", errors);
        $display("PASS: tb_ttl_74x192");
        $finish;
    end
endmodule

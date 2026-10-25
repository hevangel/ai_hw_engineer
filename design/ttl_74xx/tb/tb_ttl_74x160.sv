// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x160;
    logic clk, clr_n, load_n, enp, ent;
    logic [3:0] d, q;
    logic rco;
    ttl_74x160 dut(.clk(clk), .clr_n(clr_n), .load_n(load_n), .enp(enp), .ent(ent), .d(d), .q(q), .rco(rco));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; load_n=1; enp=1; ent=1; d=0; #1;
        if (q !== 0) errors++; clr_n=1;
        for (int i = 0; i < 12; i++) begin
            if (q !== 4'(i % 10)) errors++;
            tick;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x160: %0d errors", errors);
        $display("PASS: tb_ttl_74x160");
        $finish;
    end
endmodule

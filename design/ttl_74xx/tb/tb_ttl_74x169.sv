// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x169;
    logic clk, load_n, u_d_n, enp, ent;
    logic [3:0] d, q;
    logic rco_n;
    ttl_74x169 dut(.clk(clk), .load_n(load_n), .u_d_n(u_d_n), .enp(enp), .ent(ent), .d(d), .q(q), .rco_n(rco_n));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; load_n=0; u_d_n=1; enp=1; ent=1; d=4'd0; tick;
        load_n=1;
        for (int i = 0; i < 16; i++) begin
            if (q !== i[3:0]) errors++;
            tick;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x169: %0d errors", errors);
        $display("PASS: tb_ttl_74x169");
        $finish;
    end
endmodule

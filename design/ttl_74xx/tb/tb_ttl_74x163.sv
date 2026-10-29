// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps

module tb_ttl_74x163;
    logic clk;
    logic clr_n, load_n, enp, ent;
    logic [3:0] d, q;
    logic rco;

    ttl_74x163 dut (
        .clk(clk), .clr_n(clr_n), .load_n(load_n),
        .enp(enp), .ent(ent), .d(d), .q(q), .rco(rco)
    );

    task automatic tick;
        clk = 1'b0; #1;
        clk = 1'b1; #1;
        clk = 1'b0; #1;
    endtask

    int errors;
    initial begin
        errors = 0;
        // Sync clear
        clr_n = 1'b0; load_n = 1'b1; enp = 1'b0; ent = 1'b0; d = 4'h5; clk = 0; #1;
        tick;
        if (q !== 4'h0) errors++;
        clr_n = 1'b1;

        // Load 0xA
        load_n = 1'b0; d = 4'hA;
        tick;
        if (q !== 4'hA) errors++;
        load_n = 1'b1;

        // Count from 0xA to 0xF
        enp = 1'b1; ent = 1'b1;
        for (int i = 0; i < 5; i++) tick;
        if (q !== 4'hF) errors++;
        // rco should be high at q=F with ent=1
        if (rco !== 1'b1) errors++;
        // Disable ent and verify rco drops
        ent = 1'b0; #1;
        if (rco !== 1'b0) errors++;
        ent = 1'b1; #1;
        // Roll over to 0
        tick;
        if (q !== 4'h0) errors++;

        // Hold when enp=0
        enp = 1'b0; ent = 1'b1;
        tick;
        if (q !== 4'h0) errors++;
        // Hold when ent=0
        enp = 1'b1; ent = 1'b0;
        tick;
        if (q !== 4'h0) errors++;

        // Priority: clr_n=0 wins over load_n=0
        enp = 1'b1; ent = 1'b1; load_n = 1'b0; d = 4'hC; clr_n = 1'b0;
        tick;
        if (q !== 4'h0) errors++;
        clr_n = 1'b1; load_n = 1'b1;

        // Full count run
        for (int i = 0; i < 16; i++) begin
            if (q !== i[3:0]) errors++;
            tick;
        end

        if (errors != 0) $fatal(1, "tb_ttl_74x163: %0d errors", errors);
        $display("PASS: tb_ttl_74x163");
        $finish;
    end
endmodule

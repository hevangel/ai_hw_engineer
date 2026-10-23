// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps

module tb_ttl_74x74;
    logic [1:0] clk, d, clr_n, pre_n, q, q_n;
    ttl_74x74 dut (.clk(clk), .d(d), .clr_n(clr_n), .pre_n(pre_n),
                   .q(q), .q_n(q_n));

    task automatic tick(input int idx);
        clk[idx] = 1'b0; #1;
        clk[idx] = 1'b1; #1;
        clk[idx] = 1'b0; #1;
    endtask

    int errors;
    initial begin
        errors = 0;
        clk = 2'b00; d = 2'b00; clr_n = 2'b00; pre_n = 2'b11; #1;
        // Both flops should be cleared.
        if (q !== 2'b00) errors++;
        if (q_n !== 2'b11) errors++;

        // Release clear; nothing should latch yet.
        clr_n = 2'b11; #1;
        if (q !== 2'b00) errors++;

        // Preset flop 0 only.
        pre_n[0] = 1'b0; #1;
        if (q[0] !== 1'b1) errors++;
        pre_n[0] = 1'b1; #1;
        if (q[0] !== 1'b1) errors++; // holds

        // Clock D=1 into flop 1.
        d[1] = 1'b1; tick(1);
        if (q[1] !== 1'b1) errors++;
        // Clock D=0 into flop 1.
        d[1] = 1'b0; tick(1);
        if (q[1] !== 1'b0) errors++;

        // Asynchronous clear while clock is high should clear immediately.
        d[0] = 1'b1; tick(0);
        if (q[0] !== 1'b1) errors++;
        clr_n[0] = 1'b0; #1;
        if (q[0] !== 1'b0) errors++;
        clr_n[0] = 1'b1; #1;

        // Hold during no-edge clock idle.
        d[0] = 1'b1; tick(0);
        d[0] = 1'b0; #1; // no clock here
        if (q[0] !== 1'b1) errors++;

        // Both flops, exercise random vectors.
        for (int i = 0; i < 16; i++) begin
            clr_n = 2'b11; pre_n = 2'b11;
            d = i[1:0];
            tick(0); tick(1);
            if (q !== d) errors++;
        end

        pre_n=0;clr_n=0;#1;
        if(q!==2'b11 || q_n!==2'b11) $fatal(1,"both async controls asserted");
        pre_n=3;#1;if(q!==0 || q_n!==3) $fatal(1,"release preset with clear held");
        if (errors != 0) $fatal(1, "tb_ttl_74x74: %0d errors", errors);
        $display("PASS: tb_ttl_74x74");
        $finish;
    end
endmodule

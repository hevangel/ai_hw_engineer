// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74h71;
    logic clk, j1a,j1b,j2a,j2b,k1a,k1b,k2a,k2b, pre_n, q, q_n;
    ttl_74h71 dut(.clk(clk), .j1a(j1a), .j1b(j1b), .j2a(j2a), .j2b(j2b),
                  .k1a(k1a), .k1b(k1b), .k2a(k2a), .k2b(k2b),
                  .pre_n(pre_n), .q(q), .q_n(q_n));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        // Init then explicit preset pulse to establish q=1
        clk = 0; pre_n = 1;
        j1a = 0; j1b = 0; j2a = 0; j2b = 0;
        k1a = 0; k1b = 0; k2a = 0; k2b = 0;
        #1;
        pre_n = 0; #1;
        if (q !== 1) begin $display("step1 FAIL q=%b", q); errors++; end
        pre_n = 1; #1;

        // J via first pair (j1a&j1b=1) -> set
        j1a = 1; j1b = 1; tick;
        if (q !== 1) begin $display("step2 FAIL q=%b", q); errors++; end

        // K via second pair (k2a&k2b=1) with J off -> reset
        j1a = 0; j1b = 0; k2a = 1; k2b = 1; tick;
        if (q !== 0) begin $display("step3 FAIL q=%b", q); errors++; end

        // Both J and K via gates -> toggle from 0 to 1
        j1a = 1; j1b = 1; k2a = 1; k2b = 1; tick;
        if (q !== 1) begin $display("step4 FAIL q=%b", q); errors++; end

        // Toggle again 1 -> 0
        tick;
        if (q !== 0) begin $display("step5 FAIL q=%b", q); errors++; end

        if (errors != 0) $fatal(1, "tb_ttl_74h71: %0d errors", errors);
        $display("PASS: tb_ttl_74h71");
        $finish;
    end
endmodule

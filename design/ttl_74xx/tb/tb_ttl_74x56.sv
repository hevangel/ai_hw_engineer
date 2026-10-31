// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x56;
    logic clk, clr_n, q;
    ttl_74x56 dut(.clk(clk), .clr_n(clr_n), .q(q));
    task automatic tick; clk = 0; #1; clk = 1; #1; clk = 0; #1; endtask
    int errors, toggles;
    logic prev_q;
    initial begin
        errors = 0; toggles = 0;
        clk = 0; clr_n = 0; #1;
        if (q !== 1'b0) errors++;
        clr_n = 1; #1;
        // Run 100 cycles, count toggles
        for (int i = 0; i < 100; i++) begin
            prev_q = q;
            tick;
            if (q !== prev_q) toggles++;
        end
        // In 100 cycles with toggle every 25 ticks, expect 4 toggles
        if (toggles != 4) begin
            $display("FAIL: expected 4 toggles in 100 cycles, got %0d", toggles);
            errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x56: %0d errors", errors);
        $display("PASS: tb_ttl_74x56");
        $finish;
    end
endmodule

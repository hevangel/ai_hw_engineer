// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x97;
    logic clk, ena_n, clr_n;
    logic [5:0] rate;
    logic y, y_n;
    ttl_74x97 dut(.clk(clk), .ena_n(ena_n), .clr_n(clr_n), .rate(rate), .y(y), .y_n(y_n));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors, pulses;
    initial begin
        errors = 0; pulses = 0;
        clk=0; ena_n=0; clr_n=0; rate=6'd16; #1;
        clr_n=1;
        // Run 64 cycles, count pulses
        for (int i = 0; i < 64; i++) begin
            tick;
            if (y) pulses++;
        end
        // With rate=16, expect 16 pulses out of 64
        if (pulses != 16) begin
            $display("FAIL: rate=16, expected 16 pulses, got %0d", pulses);
            errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x97: %0d errors", errors);
        $display("PASS: tb_ttl_74x97");
        $finish;
    end
endmodule

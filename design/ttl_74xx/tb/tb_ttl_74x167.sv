// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x167;
    logic clk, ena_n, clr_n;
    logic [3:0] rate;
    logic y, y_n;
    ttl_74x167 dut(.clk(clk), .ena_n(ena_n), .clr_n(clr_n), .rate(rate), .y(y), .y_n(y_n));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors, pulses;
    initial begin
        errors = 0; pulses = 0;
        clk=0; ena_n=0; clr_n=0; rate=4'd3; #1;
        clr_n=1;
        for (int i = 0; i < 10; i++) begin
            tick;
            if (y) pulses++;
        end
        if (pulses != 3) begin $display("FAIL pulses=%0d", pulses); errors++; end
        if (errors != 0) $fatal(1, "tb_ttl_74x167: %0d errors", errors);
        $display("PASS: tb_ttl_74x167");
        $finish;
    end
endmodule

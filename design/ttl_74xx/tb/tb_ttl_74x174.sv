// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps

module tb_ttl_74x174;
    logic clk, clr_n;
    logic [5:0] d, q;
    ttl_74x174 dut (.clk(clk), .clr_n(clr_n), .d(d), .q(q));

    task automatic tick; clk = 0; #1; clk = 1; #1; clk = 0; #1; endtask

    int errors;
    initial begin
        errors = 0;
        clr_n = 0; clk = 0; d = 6'h2A; #1;
        if (q !== 6'h00) errors++;
        clr_n = 1;
        tick;
        if (q !== 6'h2A) errors++;

        d = 6'h15; tick;
        if (q !== 6'h15) errors++;

        // Async clear mid-cycle
        clr_n = 0; #1;
        if (q !== 6'h00) errors++;
        clr_n = 1;

        // Hold without clock edge
        d = 6'h3F; #1;
        if (q !== 6'h00) errors++;

        // 16 random vectors
        for (int i = 0; i < 16; i++) begin
            d = 6'($random); tick;
            if (q !== d) errors++;
        end

        if (errors != 0) $fatal(1, "tb_ttl_74x174: %0d errors", errors);
        $display("PASS: tb_ttl_74x174");
        $finish;
    end
endmodule

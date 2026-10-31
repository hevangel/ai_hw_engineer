// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps

module tb_ttl_74x273;
    logic clk, clr_n;
    logic [7:0] d, q;
    ttl_74x273 dut (.clk(clk), .clr_n(clr_n), .d(d), .q(q));

    task automatic tick; clk = 0; #1; clk = 1; #1; clk = 0; #1; endtask

    int errors;
    initial begin
        errors = 0;
        clk = 0; clr_n = 0; d = 8'hA5; #1;
        if (q !== 8'h00) errors++;
        clr_n = 1; tick;
        if (q !== 8'hA5) errors++;

        d = 8'h5A; tick;
        if (q !== 8'h5A) errors++;

        // Async clear
        clr_n = 0; #1;
        if (q !== 8'h00) errors++;
        clr_n = 1;

        // 32 random vectors
        for (int i = 0; i < 32; i++) begin
            d = 8'($random); tick;
            if (q !== d) errors++;
        end

        if (errors != 0) $fatal(1, "tb_ttl_74x273: %0d errors", errors);
        $display("PASS: tb_ttl_74x273");
        $finish;
    end
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x91;
    logic clk, a, b, q_h, q_h_n;
    ttl_74x91 dut(.clk(clk), .a(a), .b(b), .q_h(q_h), .q_h_n(q_h_n));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk = 0; a = 0; b = 0; #1;
        repeat (8) tick; // unspecified power-up contents are flushed
        a = 1; b = 1; #1;
        // Shift 1 in for 8 cycles, q_h should be 0 then 1 after 8th
        for (int i = 0; i < 7; i++) begin
            tick;
            if (q_h !== 0) errors++;
        end
        tick;
        if (q_h !== 1) errors++;
        // Now shift 0 (a=0 disables gate)
        a = 0;
        tick; tick; tick; tick; tick; tick; tick; tick;
        if (q_h !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x91: %0d errors", errors);
        $display("PASS: tb_ttl_74x91");
        $finish;
    end
endmodule

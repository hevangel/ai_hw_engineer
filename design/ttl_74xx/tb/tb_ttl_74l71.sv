// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74l71;
    logic clk, s1, s2, s3, r1, r2, r3, pre_n, clr_n, q, q_n;
    ttl_74l71 dut(.clk(clk), .s1(s1), .s2(s2), .s3(s3), .r1(r1), .r2(r2), .r3(r3),
                  .pre_n(pre_n), .clr_n(clr_n), .q(q), .q_n(q_n));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clr_n = 0; pre_n = 1; s1=0; s2=0; s3=0; r1=0; r2=0; r3=0; clk = 0; #1;
        if (q !== 0) errors++;
        clr_n = 1;
        // Set
        s1=1; s2=1; s3=1; r1=0; r2=0; r3=0; tick; if (q !== 1) errors++;
        // Reset
        s1=0; s2=0; s3=0; r1=1; r2=1; r3=1; tick; if (q !== 0) errors++;
        // Hold
        s1=0; s2=0; s3=0; r1=0; r2=0; r3=0; tick; if (q !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74l71: %0d errors", errors);
        $display("PASS: tb_ttl_74l71");
        $finish;
    end
endmodule

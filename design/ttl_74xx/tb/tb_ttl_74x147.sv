// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x147;
    logic [9:1] i_n;
    logic [3:0] y_n;
    ttl_74x147 dut(.i_n(i_n), .y_n(y_n));
    int errors;
    initial begin
        errors = 0;
        // All inputs inactive -> y_n = ~0 = 4'hF
        i_n = 9'b111111111; #1;
        if (y_n !== 4'hF) errors++;
        // Input 5 active (i_n[5]=0)
        i_n = 9'b111101111; #1;
        if (y_n !== ~4'd5) errors++;
        // Input 9 active and 5 active -> 9 wins
        i_n = 9'b011101111; #1;
        if (y_n !== ~4'd9) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x147: %0d errors", errors);
        $display("PASS: tb_ttl_74x147");
        $finish;
    end
endmodule

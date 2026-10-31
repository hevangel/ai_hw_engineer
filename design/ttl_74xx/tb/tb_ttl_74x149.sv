// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x149;
    logic [7:0] i_n, y_n;
    ttl_74x149 dut(.i_n(i_n), .y_n(y_n));
    int errors;
    initial begin
        errors = 0;
        i_n = 8'hFF; #1;
        if (y_n !== 8'hFF) errors++;
        // Input 5 active
        i_n = 8'b11011111; #1;
        if (y_n !== 8'b11011111) errors++;
        // Inputs 5 and 7 active, 7 wins
        i_n = 8'b01011111; #1;
        if (y_n !== 8'b01111111) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x149: %0d errors", errors);
        $display("PASS: tb_ttl_74x149");
        $finish;
    end
endmodule

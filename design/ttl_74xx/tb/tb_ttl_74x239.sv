// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x239;
    logic [1:0] g_n;
    logic [3:0] a;
    logic [7:0] y;
    ttl_74x239 dut(.g_n(g_n), .a(a), .y(y));
    int errors;
    initial begin
        errors = 0;
        g_n=2'b00; a=4'b00_01; #1;
        if (y !== 8'b00010010) errors++; // bit 1 and bit 4
        g_n=2'b11; #1;
        if (y !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x239: %0d errors", errors);
        $display("PASS: tb_ttl_74x239");
        $finish;
    end
endmodule

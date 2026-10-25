// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
// =============================================================================
// tb_ttl_74x00 - Exhaustive testbench for the Quad 2-input NAND gate.
//
// Walks all 2^8 = 256 input patterns and checks each of the four gate
// outputs against y[i] = ~(a[i] & b[i]).
// =============================================================================

`timescale 1ns/1ps

module tb_ttl_74x00;

    logic [3:0] a;
    logic [3:0] b;
    logic [3:0] y;
    logic [3:0] expected;

    ttl_74x00 dut (.a(a), .b(b), .y(y));

    int errors;

    initial begin
        errors = 0;
        for (int i = 0; i < 256; i++) begin
            a = i[3:0];
            b = i[7:4];
            #1;
            expected = ~(a & b);
            if (y !== expected) begin
                $display("FAIL a=%b b=%b y=%b expected=%b", a, b, y, expected);
                errors++;
            end
        end
        if (errors != 0) begin
            $fatal(1, "tb_ttl_74x00: %0d mismatches", errors);
        end
        $display("PASS: tb_ttl_74x00 (256 vectors)");
        $finish;
    end

endmodule

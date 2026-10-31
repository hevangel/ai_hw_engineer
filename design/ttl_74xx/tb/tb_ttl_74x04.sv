// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
// =============================================================================
// tb_ttl_74x04 - Exhaustive testbench for the hex inverter.
// =============================================================================

`timescale 1ns/1ps

module tb_ttl_74x04;

    logic [5:0] a;
    logic [5:0] y;
    logic [5:0] expected;

    ttl_74x04 dut (.a(a), .y(y));

    int errors;

    initial begin
        errors = 0;
        for (int i = 0; i < 64; i++) begin
            a = i[5:0];
            #1;
            expected = ~a;
            if (y !== expected) begin
                $display("FAIL a=%b y=%b expected=%b", a, y, expected);
                errors++;
            end
        end
        if (errors != 0) begin
            $fatal(1, "tb_ttl_74x04: %0d mismatches", errors);
        end
        $display("PASS: tb_ttl_74x04 (64 vectors)");
        $finish;
    end

endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps

module tb_ttl_74x244;
    logic [7:0] a, y, exp_y;
    logic oe1_n, oe2_n;

    ttl_74x244 dut (.a(a), .oe1_n(oe1_n), .oe2_n(oe2_n), .y(y));

    int errors;
    initial begin
        errors = 0;
        // Test 4 OE combinations with random data values
        for (int oe = 0; oe < 4; oe++) begin
            oe1_n = oe[0];
            oe2_n = oe[1];
            for (int v = 0; v < 8; v++) begin
                a = 8'($random);
                #1;
                exp_y[3:0] = oe1_n ? 4'h0 : a[3:0];
                exp_y[7:4] = oe2_n ? 4'h0 : a[7:4];
                if (y !== exp_y) begin
                    $display("FAIL oe1_n=%b oe2_n=%b a=%h y=%h exp=%h",
                             oe1_n, oe2_n, a, y, exp_y);
                    errors++;
                end
            end
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x244: %0d errors", errors);
        $display("PASS: tb_ttl_74x244 (32 vectors)");
        $finish;
    end
endmodule

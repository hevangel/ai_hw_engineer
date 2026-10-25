// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x137;
    logic le, en_n;
    logic [2:0] a;
    logic [7:0] y_n;
    ttl_74x137 dut(.le(le), .en_n(en_n), .a(a), .y_n(y_n));
    int errors;
    initial begin
        errors = 0;
        le = 1; en_n = 0; a = 3'd0; #1;
        if (y_n !== 8'hFE) errors++;
        a = 3'd5; #1;
        if (y_n !== 8'hDF) errors++;
        // Latch
        le = 0; a = 3'd1; #1;
        if (y_n !== 8'hDF) errors++;
        // Disable
        en_n = 1; #1;
        if (y_n !== 8'hFF) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x137: %0d errors", errors);
        $display("PASS: tb_ttl_74x137");
        $finish;
    end
endmodule

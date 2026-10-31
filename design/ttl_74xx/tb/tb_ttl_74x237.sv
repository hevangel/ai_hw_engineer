// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x237;
    logic le, en_n;
    logic [2:0] a;
    logic [7:0] y;
    ttl_74x237 dut(.le(le), .en_n(en_n), .a(a), .y(y));
    int errors;
    initial begin
        errors = 0;
        le=1; en_n=0; a=3'd3; #1;
        if (y !== 8'b00001000) errors++;
        en_n=1; #1;
        if (y !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x237: %0d errors", errors);
        $display("PASS: tb_ttl_74x237");
        $finish;
    end
endmodule

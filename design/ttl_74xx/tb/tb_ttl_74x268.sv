// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x268;
    logic le, oe_n;
    logic [5:0] d, q;
    ttl_74x268 dut(.le(le), .oe_n(oe_n), .d(d), .q(q));
    int errors;
    initial begin
        errors = 0;
        le=1; oe_n=0; d=6'h2A; #1;
        if (q !== 6'h2A) errors++;
        le=0; d=6'h15; #1;
        if (q !== 6'h2A) errors++;
        oe_n=1; #1;
        if (q !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x268: %0d errors", errors);
        $display("PASS: tb_ttl_74x268");
        $finish;
    end
endmodule

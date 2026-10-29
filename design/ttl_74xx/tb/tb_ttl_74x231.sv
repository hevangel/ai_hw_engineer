// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x231;
    logic [3:0] a, b, ya, yb;
    logic oe_a_n, oe_b;
    ttl_74x231 dut(.a(a), .b(b), .oe_a_n(oe_a_n), .oe_b(oe_b), .ya(ya), .yb(yb));
    int errors;
    initial begin
        errors = 0;
        a=4'hA; b=4'h5; oe_a_n=0; oe_b=1; #1;
        if (ya !== ~4'hA || yb !== ~4'h5) errors++;
        oe_a_n=1; oe_b=0; #1;
        if (ya !== 0 || yb !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x231: %0d errors", errors);
        $display("PASS: tb_ttl_74x231");
        $finish;
    end
endmodule

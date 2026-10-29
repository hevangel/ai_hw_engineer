// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x230;
    logic [3:0] a, b, ya, yb;
    logic [1:0] oe_n;
    ttl_74x230 dut(.a(a), .b(b), .oe_n(oe_n), .ya(ya), .yb(yb));
    int errors;
    initial begin
        errors = 0;
        a=4'hA; b=4'h5; oe_n=2'b00; #1;
        if (ya !== 4'hA || yb !== ~4'h5) errors++;
        oe_n=2'b11; #1;
        if (ya !== 0 || yb !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x230: %0d errors", errors);
        $display("PASS: tb_ttl_74x230");
        $finish;
    end
endmodule

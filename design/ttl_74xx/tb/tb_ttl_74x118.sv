// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x118;
    logic clr_n;
    logic [5:0] s, q;
    ttl_74x118 dut(.clr_n(clr_n), .s(s), .q(q));
    int errors;
    initial begin
        errors = 0;
        clr_n = 0; s = 0; #1;
        if (q !== 0) errors++;
        clr_n = 1;
        s = 6'b010101; #1;
        if (q !== 6'b010101) errors++;
        s = 6'b000000; #1;
        if (q !== 6'b010101) errors++; // hold
        s = 6'b100000; #1;
        if (q !== 6'b110101) errors++;
        clr_n = 0; #1;
        if (q !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x118: %0d errors", errors);
        $display("PASS: tb_ttl_74x118");
        $finish;
    end
endmodule

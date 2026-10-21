// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x77;
    logic [1:0] le;
    logic [3:0] d, q;
    ttl_74x77 dut(.le(le), .d(d), .q(q));
    int errors;
    initial begin
        errors = 0;
        le = 2'b11; d = 4'h0; #1; if (q !== 4'h0) errors++;
        d = 4'hA; #1; if (q !== 4'hA) errors++;
        le = 2'b10; d = 4'hF; #1;
        if (q[1:0] !== 2'b10 || q[3:2] !== 2'b11) errors++;
        le = 2'b00; d = 4'h0; #1; if (q !== 4'b1110) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x77: %0d errors", errors);
        $display("PASS: tb_ttl_74x77");
        $finish;
    end
endmodule

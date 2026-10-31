// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x278;
    logic le, cin_n, cout_n;
    logic [3:0] d, q;
    ttl_74x278 dut(.le(le), .d(d), .cin_n(cin_n), .q(q), .cout_n(cout_n));
    int errors;
    initial begin
        errors = 0;
        le=1; cin_n=0; d=4'b0101; #1;
        if (q !== 4'b0100) errors++; // priority on bit 2
        d=4'b1001; #1;
        if (q !== 4'b1000) errors++; // priority on bit 3
        d=0; #1;
        if (q !== 0 || cout_n !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x278: %0d errors", errors);
        $display("PASS: tb_ttl_74x278");
        $finish;
    end
endmodule

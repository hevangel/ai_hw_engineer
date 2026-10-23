// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x75;
    logic [1:0] le;
    logic [3:0] d, q, q_n;
    ttl_74x75 dut(.le(le), .d(d), .q(q), .q_n(q_n));
    int errors;
    initial begin
        errors = 0;
        // Open both groups
        le = 2'b11; d = 4'h0; #1;
        if (q !== 4'h0) errors++;
        d = 4'hA; #1;
        if (q !== 4'hA) errors++;
        // Close group 0, change all d
        le = 2'b10; d = 4'hF; #1;
        if (q[1:0] !== 2'b10) errors++; // held
        if (q[3:2] !== 2'b11) errors++; // open
        // Close group 1
        le = 2'b00; d = 4'h0; #1;
        if (q !== 4'b1110) errors++;
        // Open both again
        le = 2'b11; d = 4'h5; #1;
        if (q !== 4'h5) errors++;
        if (q_n !== ~q) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x75: %0d errors", errors);
        $display("PASS: tb_ttl_74x75");
        $finish;
    end
endmodule

// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x247;
    logic [3:0] bcd;
    logic lt_n, bi_n, rbi_n;
    logic [6:0] seg_n;
    logic rbo_n;
    ttl_74x247 dut(.bcd(bcd), .lt_n(lt_n), .bi_n(bi_n), .rbi_n(rbi_n), .seg_n(seg_n), .rbo_n(rbo_n));
    int errors;
    initial begin
        errors = 0;
        bi_n=1; lt_n=1; rbi_n=1;
        bcd=4'h0; #1; if (seg_n !== ~7'b1111110) errors++;
        bcd=4'h6; #1; if (seg_n !== ~7'b1011111) errors++;
        bcd=4'h9; #1; if (seg_n !== ~7'b1111011) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x247: %0d errors", errors);
        $display("PASS: tb_ttl_74x247");
        $finish;
    end
endmodule

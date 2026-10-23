// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x249;
    logic [3:0] bcd;
    logic bi_n;
    logic [6:0] seg;
    ttl_74x249 dut(.bcd(bcd), .bi_n(bi_n), .seg(seg));
    int errors;
    initial begin
        errors = 0;
        bi_n=1;
        bcd=4'h0; #1; if (seg !== 7'b1111110) errors++;
        bcd=4'h6; #1; if (seg !== 7'b1011111) errors++;
        bi_n=0; #1; if (seg !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x249: %0d errors", errors);
        $display("PASS: tb_ttl_74x249");
        $finish;
    end
endmodule

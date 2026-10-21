// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x185;
    logic [5:0] bin;
    logic [7:0] bcd;
    ttl_74x185 dut(.bin(bin), .bcd(bcd));
    int errors;
    logic [3:0] hi, lo;
    initial begin
        errors = 0;
        for (int i = 0; i < 64; i++) begin
            bin = i[5:0]; #1;
            hi = 4'(i / 10);
            lo = 4'(i % 10);
            if (bcd !== {hi, lo}) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x185: %0d errors", errors);
        $display("PASS: tb_ttl_74x185");
        $finish;
    end
endmodule

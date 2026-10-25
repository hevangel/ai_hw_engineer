// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x275;
    logic [6:0] x;
    logic [2:0] count, exp;
    ttl_74x275 dut(.x(x), .count(count));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 128; i++) begin
            x = i[6:0]; #1;
            exp = 3'($countones(x));
            if (count !== exp) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x275: %0d errors", errors);
        $display("PASS: tb_ttl_74x275");
        $finish;
    end
endmodule

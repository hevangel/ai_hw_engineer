// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x280;
    logic [8:0] data;
    logic even_out, odd_out;
    ttl_74x280 dut(.data(data), .even_out(even_out), .odd_out(odd_out));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 512; i++) begin
            data = i[8:0]; #1;
            if (odd_out !== ^data || even_out !== ~^data) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x280: %0d errors", errors);
        $display("PASS: tb_ttl_74x280");
        $finish;
    end
endmodule

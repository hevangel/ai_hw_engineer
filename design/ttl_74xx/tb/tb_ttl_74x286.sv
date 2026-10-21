// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x286;
    logic [8:0] data;
    logic oe_n, even_out, odd_out;
    ttl_74x286 dut(.data(data), .oe_n(oe_n), .even_out(even_out), .odd_out(odd_out));
    int errors;
    initial begin
        errors = 0;
        data=9'h001; oe_n=0; #1;
        if (odd_out !== 1) errors++;
        data=9'h003; #1;
        if (odd_out !== 0) errors++;
        oe_n=1; #1;
        if (odd_out !== 0 || even_out !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x286: %0d errors", errors);
        $display("PASS: tb_ttl_74x286");
        $finish;
    end
endmodule

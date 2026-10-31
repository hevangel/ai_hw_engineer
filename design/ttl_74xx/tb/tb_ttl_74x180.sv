// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x180;
    logic [7:0] data;
    logic even_in, odd_in, even_out, odd_out;
    ttl_74x180 dut(.data(data), .even_in(even_in), .odd_in(odd_in), .even_out(even_out), .odd_out(odd_out));
    int errors;
    initial begin
        errors = 0;
        even_in=1; odd_in=0;
        data=8'h00; #1; if (even_out !== 1 || odd_out !== 0) errors++;
        data=8'h01; #1; if (even_out !== 0 || odd_out !== 1) errors++;
        data=8'hFF; #1; if (even_out !== 1 || odd_out !== 0) errors++; // even number of 1s = 8
        data=8'h0F; #1; if (even_out !== 1 || odd_out !== 0) errors++; // 4 ones
        if (errors != 0) $fatal(1, "tb_ttl_74x180: %0d errors", errors);
        $display("PASS: tb_ttl_74x180");
        $finish;
    end
endmodule

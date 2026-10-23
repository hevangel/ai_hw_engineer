// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x269;
    logic clk, load_n, ctr_en_n, d_u_n;
    logic [7:0] d, q;
    logic rco_n;
    ttl_74x269 dut(.clk(clk), .load_n(load_n), .ctr_en_n(ctr_en_n), .d_u_n(d_u_n), .d(d), .q(q), .rco_n(rco_n));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; load_n=0; ctr_en_n=1; d_u_n=0; d=8'd5; tick;
        if (q !== 8'd5) errors++;
        load_n=1; ctr_en_n=0;
        tick; if (q !== 8'd6) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x269: %0d errors", errors);
        $display("PASS: tb_ttl_74x269");
        $finish;
    end
endmodule

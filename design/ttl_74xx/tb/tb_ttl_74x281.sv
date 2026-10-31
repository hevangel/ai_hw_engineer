// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x281;
    logic clk, clr_n, cin, cout;
    logic [3:0] d, q;
    ttl_74x281 dut(.clk(clk), .clr_n(clr_n), .d(d), .cin(cin), .q(q), .cout(cout));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; d=0; cin=0; #1;
        if (q !== 0) errors++;
        clr_n=1; d=4'd5; cin=0; tick;
        if (q !== 4'd5) errors++;
        d=4'd3; tick;
        if (q !== 4'd8) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x281: %0d errors", errors);
        $display("PASS: tb_ttl_74x281");
        $finish;
    end
endmodule

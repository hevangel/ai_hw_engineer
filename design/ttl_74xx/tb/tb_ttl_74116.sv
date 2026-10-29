// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74116;
    logic [1:0] le, clr_n;
    logic [7:0] d, q;
    ttl_74116 dut(.le(le), .clr_n(clr_n), .d(d), .q(q));
    int errors;
    initial begin
        errors = 0;
        clr_n = 0; le = 2'b00; d = 8'hFF; #1;
        if (q !== 8'h00) errors++;
        clr_n = 2'b11; le = 2'b11; #1;
        if (q !== 8'hFF) errors++;
        le = 2'b00; d = 8'h00; #1;
        if (q !== 8'hFF) errors++;
        clr_n[0] = 0; #1;
        if (q[3:0] !== 4'h0 || q[7:4] !== 4'hF) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74116: %0d errors", errors);
        $display("PASS: tb_ttl_74116");
        $finish;
    end
endmodule

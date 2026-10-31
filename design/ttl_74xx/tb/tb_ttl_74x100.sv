// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x100;
    logic [1:0] le;
    logic [7:0] d, q;
    ttl_74x100 dut(.le(le), .d(d), .q(q));
    int errors;
    initial begin
        errors = 0;
        le = 2'b11; d = 8'hA5; #1;
        if (q !== 8'hA5) errors++;
        le = 2'b00; d = 8'h00; #1;
        if (q !== 8'hA5) errors++;
        le = 2'b01; d = 8'hFF; #1;
        if (q[3:0] !== 4'hF || q[7:4] !== 4'hA) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x100: %0d errors", errors);
        $display("PASS: tb_ttl_74x100");
        $finish;
    end
endmodule

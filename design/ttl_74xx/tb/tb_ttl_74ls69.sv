// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74ls69;
    logic [1:0] clk, clr_n;
    logic [3:0] q0, q1;
    ttl_74ls69 dut(.clk(clk), .clr_n(clr_n), .q0(q0), .q1(q1));
    task automatic tick(input int i); clk[i]=0; #1; clk[i]=1; #1; clk[i]=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clr_n = 0; clk = 0; #1;
        if (q0 !== 0 || q1 !== 0) errors++;
        clr_n = 2'b11;
        for (int i = 0; i < 32; i++) begin
            if (q0 !== i[3:0]) errors++;
            tick(0);
        end
        if (errors != 0) $fatal(1, "tb_ttl_74ls69: %0d errors", errors);
        $display("PASS: tb_ttl_74ls69");
        $finish;
    end
endmodule

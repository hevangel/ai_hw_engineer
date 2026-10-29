// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74l68;
    logic [1:0] clk, j, k, clr_n, q, q_n;
    ttl_74l68 dut(.clk(clk), .j(j), .k(k), .clr_n(clr_n), .q(q), .q_n(q_n));
    task automatic tick(input int i); clk[i]=0; #1; clk[i]=1; #1; clk[i]=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clr_n = 2'b00; clk = 0; j = 0; k = 0; #1;
        if (q !== 2'b00) errors++;
        clr_n = 2'b11;
        // Toggle flop 0
        j[0] = 1; k[0] = 1; tick(0); if (q[0] !== 1) errors++;
        tick(0); if (q[0] !== 0) errors++;
        // Set flop 1
        j[1] = 1; k[1] = 0; tick(1); if (q[1] !== 1) errors++;
        // Reset flop 1
        j[1] = 0; k[1] = 1; tick(1); if (q[1] !== 0) errors++;
        // Async clear flop 0 mid-state
        j[0] = 1; k[0] = 0; tick(0); if (q[0] !== 1) errors++;
        clr_n[0] = 0; #1; if (q[0] !== 0) errors++;
        clr_n[0] = 1;
        if (errors != 0) $fatal(1, "tb_ttl_74l68: %0d errors", errors);
        $display("PASS: tb_ttl_74l68");
        $finish;
    end
endmodule

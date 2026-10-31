// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74120;
    logic [1:0] clk, async_in, sync_out;
    ttl_74120 dut(.clk(clk), .async_in(async_in), .sync_out(sync_out));
    task automatic tick(input int i); clk[i]=0; #1; clk[i]=1; #1; clk[i]=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk = 0; async_in = 0; #1;
        async_in[0] = 1; tick(0); tick(0);  // 2 cycles for sync
        if (sync_out[0] !== 1) errors++;
        async_in[0] = 0; tick(0); tick(0);
        if (sync_out[0] !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74120: %0d errors", errors);
        $display("PASS: tb_ttl_74120");
        $finish;
    end
endmodule

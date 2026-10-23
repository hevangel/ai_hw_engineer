// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x170;
    logic clk;
    logic [1:0] wr_addr, rd_addr;
    logic [3:0] wr_data, rd_data;
    logic we_n;
    ttl_74x170 dut(.clk(clk), .wr_addr(wr_addr), .wr_data(wr_data), .we_n(we_n), .rd_addr(rd_addr), .rd_data(rd_data));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; we_n=0;
        wr_addr=2'd0; wr_data=4'hA; tick;
        wr_addr=2'd1; wr_data=4'h5; tick;
        wr_addr=2'd2; wr_data=4'hF; tick;
        we_n=1;
        rd_addr=2'd0; #1; if (rd_data !== 4'hA) errors++;
        rd_addr=2'd1; #1; if (rd_data !== 4'h5) errors++;
        rd_addr=2'd2; #1; if (rd_data !== 4'hF) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x170: %0d errors", errors);
        $display("PASS: tb_ttl_74x170");
        $finish;
    end
endmodule

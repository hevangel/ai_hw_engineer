// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x172;
    logic clk;
    logic [2:0] wr_addr, rd_a_addr, rd_b_addr;
    logic [1:0] wr_data, rd_a_data, rd_b_data;
    logic we_n;
    ttl_74x172 dut(.clk(clk), .wr_addr(wr_addr), .wr_data(wr_data), .we_n(we_n),
                   .rd_a_addr(rd_a_addr), .rd_b_addr(rd_b_addr),
                   .rd_a_data(rd_a_data), .rd_b_data(rd_b_data));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; we_n=0;
        for (int i = 0; i < 8; i++) begin
            wr_addr=i[2:0]; wr_data=i[1:0]; tick;
        end
        we_n=1;
        for (int i = 0; i < 8; i++) begin
            rd_a_addr = i[2:0];
            rd_b_addr = 3'((i + 1) & 7);
            #1;
            if (rd_a_data !== i[1:0]) errors++;
            if (rd_b_data !== 2'((i + 1) & 3)) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x172: %0d errors", errors);
        $display("PASS: tb_ttl_74x172");
        $finish;
    end
endmodule

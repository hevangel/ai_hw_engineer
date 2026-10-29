`timescale 1ns/1ps
module tb_ttl_74x411;
    logic clk, clr_n, inc_wr, inc_rd, empty, full;
    logic [3:0] wr_ptr, rd_ptr;
    ttl_74x411 dut(.clk(clk), .clr_n(clr_n), .inc_wr(inc_wr), .inc_rd(inc_rd), .wr_ptr(wr_ptr), .rd_ptr(rd_ptr), .empty(empty), .full(full));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; inc_wr=0; inc_rd=0; #1;
        if (!empty) errors++;
        clr_n=1;
        inc_wr=1; tick; tick;
        if (wr_ptr !== 4'h2 || empty) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x411: %0d errors", errors);
        $display("PASS: tb_ttl_74x411");
        $finish;
    end
endmodule

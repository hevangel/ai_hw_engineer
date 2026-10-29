`timescale 1ns/1ps
module tb_ttl_74x491;
    logic clk, clr_n, u_d_n, set_msb_n;
    logic [9:0] q;
    ttl_74x491 dut(.clk(clk), .clr_n(clr_n), .u_d_n(u_d_n), .set_msb_n(set_msb_n), .q(q));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; u_d_n=0; set_msb_n=1; #1;
        clr_n=1;
        tick; if (q !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x491: %0d errors", errors);
        $display("PASS: tb_ttl_74x491");
        $finish;
    end
endmodule

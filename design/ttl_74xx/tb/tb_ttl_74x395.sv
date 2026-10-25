`timescale 1ns/1ps
module tb_ttl_74x395;
    logic clk, clr_n, oe_n, s_l, din;
    logic [3:0] p, q;
    ttl_74x395 dut(.clk(clk), .clr_n(clr_n), .oe_n(oe_n), .s_l(s_l), .din(din), .p(p), .q(q));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; oe_n=0; s_l=1; din=0; p=4'hA; #1;
        if (q !== 0) errors++;
        clr_n=1; tick;
        if (q !== 4'hA) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x395: %0d errors", errors);
        $display("PASS: tb_ttl_74x395");
        $finish;
    end
endmodule

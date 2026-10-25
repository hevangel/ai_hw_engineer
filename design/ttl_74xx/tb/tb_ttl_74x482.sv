`timescale 1ns/1ps
module tb_ttl_74x482;
    logic clk, clr_n, ce_n;
    logic [3:0] din, q;
    logic zero, neg;
    ttl_74x482 dut(.clk(clk), .clr_n(clr_n), .din(din), .ce_n(ce_n), .q(q), .zero(zero), .neg(neg));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; ce_n=1; din=0; #1;
        if (!zero) errors++;
        clr_n=1; ce_n=0; din=4'b1000; tick;
        if (!neg) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x482: %0d errors", errors);
        $display("PASS: tb_ttl_74x482");
        $finish;
    end
endmodule

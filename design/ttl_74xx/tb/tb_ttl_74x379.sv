`timescale 1ns/1ps
module tb_ttl_74x379;
    logic clk, ce_n;
    logic [3:0] d, q, q_n;
    ttl_74x379 dut(.clk(clk), .ce_n(ce_n), .d(d), .q(q), .q_n(q_n));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; ce_n=0; d=4'hA; tick;
        if (q !== 4'hA || q_n !== 4'h5) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x379: %0d errors", errors);
        $display("PASS: tb_ttl_74x379");
        $finish;
    end
endmodule

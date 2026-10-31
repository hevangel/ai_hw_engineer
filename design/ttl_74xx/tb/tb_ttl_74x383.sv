`timescale 1ns/1ps
module tb_ttl_74x383;
    logic clk;
    logic [7:0] d, q;
    ttl_74x383 dut(.clk(clk), .d(d), .q(q));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; d=8'hC3; tick;
        if (q !== 8'hC3) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x383: %0d errors", errors);
        $display("PASS: tb_ttl_74x383");
        $finish;
    end
endmodule

`timescale 1ns/1ps
module tb_ttl_74x388;
    logic clk;
    logic [3:0] d, q;
    ttl_74x388 dut(.clk(clk), .d(d), .q(q));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; d=4'hA; tick;
        if (q !== 4'hA) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x388: %0d errors", errors);
        $display("PASS: tb_ttl_74x388");
        $finish;
    end
endmodule

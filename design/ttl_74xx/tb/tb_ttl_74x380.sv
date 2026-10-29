`timescale 1ns/1ps
module tb_ttl_74x380;
    logic clk;
    logic [1:0] s;
    logic [7:0] d, q;
    ttl_74x380 dut(.clk(clk), .s(s), .d(d), .q(q));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; s=2'b01; d=0; tick;
        if (q !== 0) errors++;
        s=2'b10; d=8'h5A; tick;
        if (q !== 8'h5A) errors++;
        s=2'b11; tick;
        if (q !== ~8'h5A) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x380: %0d errors", errors);
        $display("PASS: tb_ttl_74x380");
        $finish;
    end
endmodule

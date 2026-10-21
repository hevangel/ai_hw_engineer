`timescale 1ns/1ps
module tb_ttl_74x399;
    logic clk, select;
    logic [3:0] a, b, q;
    ttl_74x399 dut(.clk(clk), .select(select), .a(a), .b(b), .q(q));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; select=1; a=4'h5; b=4'hA; tick;
        if (q !== 4'hA) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x399: %0d errors", errors);
        $display("PASS: tb_ttl_74x399");
        $finish;
    end
endmodule

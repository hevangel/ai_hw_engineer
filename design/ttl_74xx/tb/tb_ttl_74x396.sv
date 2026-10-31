`timescale 1ns/1ps
module tb_ttl_74x396;
    logic clk, ce_n;
    logic [7:0] d, q;
    ttl_74x396 dut(.clk(clk), .ce_n(ce_n), .d(d), .q(q));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; ce_n=0; d=8'hF0; tick;
        if (q !== 8'hF0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x396: %0d errors", errors);
        $display("PASS: tb_ttl_74x396");
        $finish;
    end
endmodule

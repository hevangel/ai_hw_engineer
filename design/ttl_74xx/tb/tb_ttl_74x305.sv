`timescale 1ns/1ps
module tb_ttl_74x305;
    logic clk, clr_n;
    logic [7:0] y;
    ttl_74x305 dut(.clk(clk), .clr_n(clr_n), .y(y));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; #1;
        if (y !== 8'hF0) errors++;
        clr_n=1; tick;
        if (y !== 8'h0F) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x305: %0d errors", errors);
        $display("PASS: tb_ttl_74x305");
        $finish;
    end
endmodule

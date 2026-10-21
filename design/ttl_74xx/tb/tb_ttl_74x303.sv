`timescale 1ns/1ps
module tb_ttl_74x303;
    logic clk, clr_n;
    logic [7:0] y;
    ttl_74x303 dut(.clk(clk), .clr_n(clr_n), .y(y));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; #1;
        if (y[5:0] !== 0 || y[7:6] !== 2'b11) errors++;
        clr_n=1;
        tick;
        if (y[5:0] !== 6'h3F || y[7:6] !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x303: %0d errors", errors);
        $display("PASS: tb_ttl_74x303");
        $finish;
    end
endmodule

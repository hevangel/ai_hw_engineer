`timescale 1ns/1ps
module tb_ttl_74x376;
    logic clk, clr_n;
    logic [3:0] j, k_n, q;
    ttl_74x376 dut(.clk(clk), .clr_n(clr_n), .j(j), .k_n(k_n), .q(q));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; j=0; k_n=4'hF; #1;
        if (q !== 0) errors++;
        clr_n=1;
        j=4'hF; k_n=4'hF; tick;
        if (q !== 4'hF) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x376: %0d errors", errors);
        $display("PASS: tb_ttl_74x376");
        $finish;
    end
endmodule

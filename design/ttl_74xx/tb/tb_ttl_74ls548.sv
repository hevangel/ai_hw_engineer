`timescale 1ns/1ps
module tb_ttl_74ls548;
    logic clk, clr_n;
    logic [7:0] d, q;
    ttl_74ls548 dut(.*);
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors=0; clk=0; clr_n=1; #1; clr_n=0; #1; clr_n=1;
        d=8'h11; tick; // s1<=11
        d=8'h22; tick; // q<=11, s1<=22
        if (q !== 8'h11) errors++;
        tick;          // q<=22
        if (q !== 8'h22) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74ls548: %0d errors", errors);
        $display("PASS: tb_ttl_74ls548");
        $finish;
    end
endmodule

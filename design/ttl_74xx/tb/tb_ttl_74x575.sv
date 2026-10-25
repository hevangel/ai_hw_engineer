`timescale 1ns/1ps
module tb_ttl_74x575;
    logic clk, oe_n, clr_n, hiz;
    logic [7:0] d, q;
    ttl_74x575 dut(.*);
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors=0; oe_n=0; clr_n=1; d=8'h99; tick;
        if (q !== 8'h99) errors++;
        clr_n=0; tick; if (q !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x575: %0d errors", errors);
        $display("PASS: tb_ttl_74x575");
        $finish;
    end
endmodule

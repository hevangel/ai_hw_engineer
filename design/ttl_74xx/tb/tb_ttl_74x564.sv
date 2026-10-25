`timescale 1ns/1ps
module tb_ttl_74x564;
    logic clk, oe_n, hiz;
    logic [7:0] d, q_n;
    ttl_74x564 dut(.*);
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors=0; oe_n=0; d=8'hC3; tick;
        if (q_n !== 8'h3C) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x564: %0d errors", errors);
        $display("PASS: tb_ttl_74x564");
        $finish;
    end
endmodule

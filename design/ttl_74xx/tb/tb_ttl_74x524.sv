`timescale 1ns/1ps
module tb_ttl_74x524;
    logic clk, g_n;
    logic [7:0] p, q;
    logic p_eq_q;
    ttl_74x524 dut(.*);
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors=0; g_n=0;
        p=8'h33; q=8'h33; tick; #1;
        if (p_eq_q !== 1) errors++;
        p=8'h33; q=8'h44; tick; #1;
        if (p_eq_q !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x524: %0d errors", errors);
        $display("PASS: tb_ttl_74x524");
        $finish;
    end
endmodule

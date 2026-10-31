`timescale 1ns/1ps
module tb_ttl_74x7075;
    logic [1:0] inv_a, inv_y, nand_a, nand_b, nand_y;
    logic clk1, clr1_n, pre1_n, d1, q1, q1_n;
    logic clk2, clr2_n, pre2_n, d2, q2, q2_n;
    ttl_74x7075 dut(.*);
    int errors;
    initial begin
        errors = 0;
        inv_a = 2'b00; nand_a = 2'b11; nand_b = 2'b10;
        clk1 = 0; clk2 = 0; d1 = 0; d2 = 0;
        clr1_n = 1; pre1_n = 1; clr2_n = 1; pre2_n = 1;
        #1; clr1_n = 0; clr2_n = 0; #1; clr1_n = 1; clr2_n = 1; #1;
        if (inv_y !== 2'b11 || nand_y !== 2'b01) errors++;
        if (q1 !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x7075: %0d errors", errors);
        $display("PASS: tb_ttl_74x7075");
        $finish;
    end
endmodule

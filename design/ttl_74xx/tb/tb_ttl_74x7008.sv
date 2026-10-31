`timescale 1ns/1ps
module tb_ttl_74x7008;
    logic [1:0] inv_a, inv_y;
    logic [2:0] nand_a, nand_b, nand_y;
    logic [2:0] nor_a, nor_b, nor_y;
    ttl_74x7008 dut(.*);
    int errors;
    initial begin
        errors = 0;
        inv_a = 2'b10;
        nand_a = 3'b111; nand_b = 3'b110;
        nor_a  = 3'b000; nor_b  = 3'b001; #1;
        if (inv_y !== 2'b01) errors++;
        if (nand_y !== 3'b001) errors++;
        if (nor_y !== 3'b110) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x7008: %0d errors", errors);
        $display("PASS: tb_ttl_74x7008");
        $finish;
    end
endmodule

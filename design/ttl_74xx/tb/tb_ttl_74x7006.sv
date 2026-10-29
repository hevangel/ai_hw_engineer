`timescale 1ns/1ps
module tb_ttl_74x7006;
    logic [1:0] inv_a, inv_y;
    logic [2:0] nand3_a, nor3_a;
    logic [3:0] nand4_a, nor4_a;
    logic nand3_y, nand4_y, nor3_y, nor4_y;
    ttl_74x7006 dut(.*);
    int errors;
    initial begin
        errors = 0;
        inv_a = 2'b01; nand3_a = 3'b111; nand4_a = 4'b1111;
        nor3_a = 3'b000; nor4_a = 4'b0000; #1;
        if (inv_y !== 2'b10) errors++;
        if (nand3_y !== 0 || nand4_y !== 0) errors++;
        if (nor3_y !== 1 || nor4_y !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x7006: %0d errors", errors);
        $display("PASS: tb_ttl_74x7006");
        $finish;
    end
endmodule

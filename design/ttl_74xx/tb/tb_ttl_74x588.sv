`timescale 1ns/1ps
module tb_ttl_74x588;
    logic dir, oe_n, a_hiz, b_hiz;
    logic [7:0] a_in, b_in, a_out, b_out;
    ttl_74x588 dut(.*);
    int errors;
    initial begin
        errors=0; oe_n=0;
        dir=1; a_in=8'h99; b_in=0; #1;
        if (b_out !== 8'h99) errors++;
        dir=0; b_in=8'h66; a_in=0; #1;
        if (a_out !== 8'h66) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x588: %0d errors", errors);
        $display("PASS: tb_ttl_74x588");
        $finish;
    end
endmodule

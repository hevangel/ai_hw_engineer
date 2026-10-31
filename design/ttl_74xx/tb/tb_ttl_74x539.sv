`timescale 1ns/1ps
module tb_ttl_74x539;
    logic [1:0] a, b;
    logic ga_n, gb_n, hiz_a, hiz_b;
    logic [3:0] ya_n, yb_n;
    ttl_74x539 dut(.*);
    int errors;
    initial begin
        errors=0; ga_n=0; gb_n=0;
        a=2'd1; b=2'd2; #1;
        if (ya_n !== 4'b1101) errors++;
        if (yb_n !== 4'b1011) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x539: %0d errors", errors);
        $display("PASS: tb_ttl_74x539");
        $finish;
    end
endmodule

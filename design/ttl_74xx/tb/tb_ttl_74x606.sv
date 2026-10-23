`timescale 1ns/1ps
module tb_ttl_74x606;
    logic sel, le, oe_n, hiz;
    logic [7:0] a, b, y;
    ttl_74x606 dut(.*);
    int errors;
    initial begin
        errors=0; oe_n=0; le=1;
        a=8'h01; b=8'h80; sel=1; #1; if (y !== 8'h80) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x606: %0d errors", errors);
        $display("PASS: tb_ttl_74x606");
        $finish;
    end
endmodule

`timescale 1ns/1ps
module tb_ttl_74x573;
    logic le, oe_n, hiz;
    logic [7:0] d, q;
    ttl_74x573 dut(.*);
    int errors;
    initial begin
        errors=0; oe_n=0; le=1; d=8'h42; #1;
        if (q !== 8'h42) errors++;
        le=0; d=8'hFF; #1; if (q !== 8'h42) errors++;
        oe_n=1; #1; if (hiz !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x573: %0d errors", errors);
        $display("PASS: tb_ttl_74x573");
        $finish;
    end
endmodule

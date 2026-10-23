`timescale 1ns/1ps
module tb_ttl_74x533;
    logic le, oe_n, hiz;
    logic [7:0] d, q_n;
    ttl_74x533 dut(.*);
    int errors;
    initial begin
        errors=0; oe_n=0; le=1; d=8'h3C; #1;
        if (q_n !== 8'hC3) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x533: %0d errors", errors);
        $display("PASS: tb_ttl_74x533");
        $finish;
    end
endmodule

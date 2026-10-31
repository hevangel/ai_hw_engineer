`timescale 1ns/1ps
module tb_ttl_74x563;
    logic le, oe_n, hiz;
    logic [7:0] d, q_n;
    ttl_74x563 dut(.*);
    int errors;
    initial begin
        errors=0; oe_n=0; le=1; d=8'h00; #1;
        if (q_n !== 8'hFF) errors++;
        d=8'hFF; #1; if (q_n !== 8'h00) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x563: %0d errors", errors);
        $display("PASS: tb_ttl_74x563");
        $finish;
    end
endmodule

`timescale 1ns/1ps
module tb_ttl_74x2533;
    logic le, oe_n;
    logic [7:0] d, q_n;
    logic hiz;
    ttl_74x2533 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; le = 1; d = 8'h5A; #1;
        if (q_n !== 8'hA5) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2533: %0d errors", errors);
        $display("PASS: tb_ttl_74x2533");
        $finish;
    end
endmodule

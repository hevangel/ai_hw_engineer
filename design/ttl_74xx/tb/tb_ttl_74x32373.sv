`timescale 1ns/1ps
module tb_ttl_74x32373;
    logic le, oe_n;
    logic [31:0] d, q;
    logic hiz;
    ttl_74x32373 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; le = 1; d = 32'hAABBCCDD; #1;
        if (q !== 32'hAABBCCDD) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x32373: %0d errors", errors);
        $display("PASS: tb_ttl_74x32373");
        $finish;
    end
endmodule

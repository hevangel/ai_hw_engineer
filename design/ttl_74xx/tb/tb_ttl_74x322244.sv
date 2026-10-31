`timescale 1ns/1ps
module tb_ttl_74x322244;
    logic oe_n;
    logic [31:0] a, y;
    logic hiz;
    ttl_74x322244 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; a = 32'hFEEDC0DE; #1;
        if (y !== 32'hFEEDC0DE) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x322244: %0d errors", errors);
        $display("PASS: tb_ttl_74x322244");
        $finish;
    end
endmodule

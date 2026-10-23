`timescale 1ns/1ps
module tb_ttl_74x8838;
    logic dir;
    logic [5:0] shft;
    logic [63:0] a, y;
    ttl_74x8838 dut(.*);
    int errors;
    initial begin
        errors = 0;
        dir = 0; shft = 6'd0; a = 64'hDEAD_BEEF_CAFE_BABE; #1;
        if (y !== 64'hDEAD_BEEF_CAFE_BABE) errors++;
        dir = 0; shft = 6'd4; #1;
        if (y !== {a[59:0], a[63:60]}) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x8838: %0d errors", errors);
        $display("PASS: tb_ttl_74x8838");
        $finish;
    end
endmodule

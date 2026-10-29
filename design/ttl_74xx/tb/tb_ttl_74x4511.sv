`timescale 1ns/1ps
module tb_ttl_74x4511;
    logic le_n, bl_n, lt_n;
    logic [3:0] d;
    logic [6:0] seg;
    ttl_74x4511 dut(.*);
    int errors;
    initial begin
        errors = 0;
        le_n = 0; bl_n = 1; lt_n = 1; d = 4'd8; #1;
        if (seg !== 7'b1111111) errors++;
        lt_n = 0; #1;
        if (seg !== 7'b1111111) errors++;
        lt_n = 1; bl_n = 0; #1;
        if (seg !== 7'b0000000) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x4511: %0d errors", errors);
        $display("PASS: tb_ttl_74x4511");
        $finish;
    end
endmodule

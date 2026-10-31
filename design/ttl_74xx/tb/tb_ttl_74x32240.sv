`timescale 1ns/1ps
module tb_ttl_74x32240;
    logic [31:0] a, y;
    logic oe1_n, oe2_n, oe3_n, oe4_n;
    ttl_74x32240 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe1_n = 0; oe2_n = 0; oe3_n = 0; oe4_n = 0;
        a = 32'hDEAD_BEEF; #1;
        if (y !== ~a) errors++;
        oe1_n = 1; oe2_n = 1; oe3_n = 1; oe4_n = 1; #1;
        if (y !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x32240: %0d errors", errors);
        $display("PASS: tb_ttl_74x32240");
        $finish;
    end
endmodule
